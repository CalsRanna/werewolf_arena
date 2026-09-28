// 记录式反向代理：给 werewolf_arena 记账用，零应用代码改动。
//
// 原理：openai_dart 的 URL = baseUrl + '/chat/completions'。把配置里的
// base_url 指向本代理，它原样转发到上游（默认 OpenRouter），并把每次调用的
// 模型 / 输入输出 token / 耗时 / 归属步骤追加写入 JSONL。
//
// 无第三方依赖（只用 dart:io / dart:convert），可直接运行：
//
//   export OPENAI_API_KEY=sk-or-...
//   dart tool/llm_proxy_recorder.dart
//   # 另一个终端里跑对局：
//   dart run bin/main.dart -g
//
// 参数：
//   --port     监听端口，默认 8787
//   --upstream 上游基址，默认 https://openrouter.ai/api/v1
//   --log      记录文件，默认 tool/llm_calls.jsonl
//   --timeout  单次上游请求超时秒数，默认 300

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 各推理步骤的系统提示词特征串 -> 归属名。
/// 匹配时按特征串长度降序，避免短串把长串吃掉。
const Map<String, String> _stepMarkers = {
  '你是狼人杀战术指令专家': 'tactical_directive',
  '你是狼人杀发言质量评估专家': 'self_reflection',
  '你是狼人杀身份推理专家': 'identity_inference',
  '你是狼人杀策略规划专家': 'strategy_planning',
  '你是狼人杀游戏分析专家': 'fact_analysis',
  '你是狼人杀行动审查专家': 'action_rehearsal',
  '你是狼人杀表演专家': 'mask_selection',
  '你是狼人杀战术专家': 'playbook_selection',
  // staged 引擎（本项目默认）三阶段。注意核心认知与链式发言生成共用
  // 同一段提示词开头，这里合并成一个标签，避免误标。
  '你是狼人杀游戏的数据分析助手': 'stage:preprocessing',
  '你是狼人杀游戏的安全检查助手': 'stage:postprocessing',
  '你是一名真实的狼人杀玩家': 'core_cognition_or_speech',
  // 角色技能类（夜晚行动/警长竞选/遗言等）。这些不走九步推理链，
  // 是独立的一次调用，输出里带较长的推理文本。
  '现在是警长竞选的上警阶段': 'skill:campaign',
  '狼人战术会议': 'skill:conspire',
  '现在是白天讨论阶段': 'skill:discuss',
  '作为女巫，你可以选择使用解药': 'skill:heal',
  '作为预言家，你需要选择查验目标': 'skill:investigate',
  '作为狼人，你需要选择击杀目标': 'skill:kill',
  '作为女巫，你可以选择使用毒药': 'skill:poison',
  '作为守卫，你需要选择守护目标': 'skill:protect',
  '现在是警长竞选发言阶段': 'skill:sheriff_speech',
  '现在是警长投票阶段': 'skill:sheriff_vote',
  '你是猎人，刚刚死亡': 'skill:shoot',
  '你已经被投票出局了': 'skill:testament',
  '你是警长，即将出局': 'skill:transfer_badge',
  '现在是投票阶段，请选择你要投票出局的玩家': 'skill:vote',
  '现在是退水环节': 'skill:withdraw',
};

/// 不应转发的逐跳头；accept-encoding 去掉以保证响应可解析。
const Set<String> _stripRequestHeaders = {
  'host',
  'content-length',
  'connection',
  'transfer-encoding',
  'accept-encoding',
};

/// 上游响应里不应回传的头（长度/编码由本代理重算）。
const Set<String> _stripResponseHeaders = {
  'content-length',
  'content-encoding',
  'transfer-encoding',
  'connection',
};

class _Options {
  _Options({
    required this.port,
    required this.upstream,
    required this.logPath,
    required this.timeoutSeconds,
    required this.captureDir,
    required this.captureStep,
    required this.captureLimit,
    required this.echo,
    required this.echoLimit,
  });

  final int port;
  final String upstream;
  final String logPath;
  final int timeoutSeconds;

  /// 非空时把匹配 [captureStep] 的请求体/响应体落盘，供离线 A/B 用。
  final String captureDir;
  final String captureStep;
  final int captureLimit;

  /// 把每次调用的模型真实输出回显到终端。
  final bool echo;

  /// 回显时的字符上限；0 表示不截断。完整内容仍以 --capture 落盘为准。
  final int echoLimit;
}

_Options _parseArgs(List<String> args) {
  var port = 8787;
  var upstream = 'https://openrouter.ai/api/v1';
  var logPath = 'tool/llm_calls.jsonl';
  var timeout = 300;
  var captureDir = '';
  var captureStep = 'stage:preprocessing';
  var captureLimit = 30;
  var echo = false;
  var echoLimit = 1200;

  for (var i = 0; i < args.length; i++) {
    String? next() => i + 1 < args.length ? args[++i] : null;
    switch (args[i]) {
      case '--port':
        port = int.tryParse(next() ?? '') ?? port;
      case '--upstream':
        upstream = next() ?? upstream;
      case '--log':
        logPath = next() ?? logPath;
      case '--timeout':
        timeout = int.tryParse(next() ?? '') ?? timeout;
      case '--capture':
        captureDir = next() ?? captureDir;
      case '--capture-step':
        captureStep = next() ?? captureStep;
      case '--capture-limit':
        captureLimit = int.tryParse(next() ?? '') ?? captureLimit;
      case '--echo':
        echo = true;
      case '--echo-limit':
        echoLimit = int.tryParse(next() ?? '') ?? echoLimit;
      case '--help':
      case '-h':
        stdout.writeln(
          'dart tool/llm_proxy_recorder.dart '
          '[--port 8787] [--upstream https://openrouter.ai/api/v1] '
          '[--log tool/llm_calls.jsonl] [--timeout 300] '
          '[--capture DIR] [--capture-step 前缀] [--capture-limit N] '
          '[--echo] [--echo-limit N]\n'
          '\n'
          '  --echo        把每次调用的模型真实输出打到终端'
          '（chat 取 message.content，\n'
          '                System One 取 answers）。--echo-limit 0 表示不截断。',
        );
        exit(0);
    }
  }
  // 去掉尾部斜杠，避免拼出 //chat/completions
  while (upstream.endsWith('/')) {
    upstream = upstream.substring(0, upstream.length - 1);
  }
  return _Options(
    port: port,
    upstream: upstream,
    logPath: logPath,
    timeoutSeconds: timeout,
    captureDir: captureDir,
    captureStep: captureStep,
    captureLimit: captureLimit,
    echo: echo,
    echoLimit: echoLimit,
  );
}

/// 决策接口（System One / Decisions）的请求体特征是 state + questions，
/// 与 chat completions 的 messages 完全不同，单独归一类。
bool _isDecisionsRequest(String body) =>
    body.contains('"questions"') && body.contains('"state"');

String _classify(String body) {
  if (_isDecisionsRequest(body)) return 'jev_systemone';
  final keys = _stepMarkers.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    if (body.contains(key)) return _stepMarkers[key]!;
  }
  return 'other';
}

String _modelOf(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map && json['model'] is String) return json['model'] as String;
  } catch (_) {
    // 非 JSON 请求体（理论上不会出现）
  }
  return 'unknown';
}

Future<List<int>> _readAll(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final logFile = File(opts.logPath);
  await logFile.parent.create(recursive: true);
  final sink = logFile.openWrite(mode: FileMode.append);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

  final perStepCalls = <String, int>{};
  var totalIn = 0;
  var totalOut = 0;
  var totalCalls = 0;
  var missingUsage = 0;
  var captureCount = 0;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, opts.port);

  // Ctrl+C 时先输出汇总再退出，避免长对局中途没有总量视图
  var shuttingDown = false;
  ProcessSignal.sigint.watch().listen((_) async {
    if (shuttingDown) return;
    shuttingDown = true;
    _printSummary(totalCalls, totalIn, totalOut, missingUsage, perStepCalls);
    await sink.flush();
    await sink.close();
    await server.close(force: true);
    exit(0);
  });

  stdout.writeln('记录代理已启动');
  stdout.writeln('  监听      http://127.0.0.1:${opts.port}');
  stdout.writeln('  上游      ${opts.upstream}');
  stdout.writeln('  记录文件  ${logFile.path}');
  stdout.writeln(
    '  base_url  http://127.0.0.1:${opts.port}   （不带 /v1，'
    'openai_dart 会自己拼 /chat/completions）',
  );
  stdout.writeln('等待请求（Ctrl+C 结束）...\n');
  if (opts.echo) {
    stdout.writeln(
      '回显已开启：每次调用的模型输出会直接打在这里'
      '${opts.echoLimit > 0 ? '（每次截断到 ${opts.echoLimit} 字符，'
          '--echo-limit 0 可关闭截断）' : '（不截断）'}。\n',
    );
  }

  await for (final request in server) {
    // 不 await：多个玩家的请求需要并发转发，否则会串行化拖慢对局
    unawaited(() async {
      final bodyBytes = await _readAll(request);
      final bodyText = utf8.decode(bodyBytes, allowMalformed: true);
      final step = _classify(bodyText);
      final requestModel = _modelOf(bodyText);
      final stopwatch = Stopwatch()..start();

      var status = 0;
      var responseBytes = <int>[];
      Object? parsedJson;
      var usageIn = 0;
      var usageOut = 0;
      var responseModel = requestModel;
      String? errorNote;
      double? reportedCost;
      // 上游响应头需要跨 try 使用，先收集再回传
      final responseHeaders = <String, List<String>>{};

      try {
        // 兼容 base_url 带不带 /v1 两种写法，避免拼出 /v1/v1/chat/completions
        var path = request.uri.path;
        if (path.startsWith('/v1/') && opts.upstream.endsWith('/v1')) {
          path = path.substring(3);
        }
        final uri = Uri.parse(
          '${opts.upstream}$path'
          '${request.uri.hasQuery ? '?${request.uri.query}' : ''}',
        );
        final upstreamRequest = await client.postUrl(uri);
        request.headers.forEach((name, values) {
          if (_stripRequestHeaders.contains(name.toLowerCase())) return;
          for (final value in values) {
            upstreamRequest.headers.add(name, value);
          }
        });
        // 先声明长度再写入：Dart 要求 contentLength 在 body 之前设置，
        // 否则退化成 chunked 传输，且设置会抛 "headers are not mutable"
        upstreamRequest.contentLength = bodyBytes.length;
        upstreamRequest.add(bodyBytes);
        final response = await upstreamRequest.close().timeout(
          Duration(seconds: opts.timeoutSeconds),
        );
        status = response.statusCode;
        responseBytes = await _readAll(response);
        response.headers.forEach((name, values) {
          if (_stripResponseHeaders.contains(name.toLowerCase())) return;
          responseHeaders[name] = values;
        });

        final text = utf8.decode(responseBytes, allowMalformed: true);
        try {
          final json = jsonDecode(text);
          parsedJson = json;
          if (json is Map) {
            if (json['model'] is String) {
              responseModel = json['model'] as String;
            }
            final usage = json['usage'];
            if (usage is Map) {
              // chat completions: prompt_tokens/completion_tokens
              // System One / decisions: input_tokens/output_tokens
              usageIn = (usage['prompt_tokens'] as num?)?.toInt() ??
                  (usage['input_tokens'] as num?)?.toInt() ??
                  0;
              usageOut = (usage['completion_tokens'] as num?)?.toInt() ??
                  (usage['output_tokens'] as num?)?.toInt() ??
                  0;
              // 上游直接回报的费用，比按单价推算更准
              reportedCost = (usage['cost'] as num?)?.toDouble();
            }
            if (json['error'] != null) {
              errorNote = json['error'].toString();
            }
          }
        } catch (_) {
          errorNote = 'non-json response';
        }
      } catch (error) {
        status = 599;
        errorNote = error.toString();
        responseBytes = utf8.encode(
          jsonEncode({'error': {'message': 'proxy failure: $error'}}),
        );
      }

      stopwatch.stop();
      if (usageIn == 0 && usageOut == 0 && status < 400) missingUsage++;

      totalCalls++;
      totalIn += usageIn;
      totalOut += usageOut;
      perStepCalls[step] = (perStepCalls[step] ?? 0) + 1;

      sink.writeln(
        jsonEncode({
          'ts': DateTime.now().toIso8601String(),
          'step': step,
          'model': responseModel,
          'status': status,
          'prompt_tokens': usageIn,
          'completion_tokens': usageOut,
          'latency_ms': stopwatch.elapsedMilliseconds,
          'cost': ?reportedCost,
          'error': ?errorNote,
        }),
      );
      await sink.flush();

      // 按需落盘请求/响应体，供离线逐字段比对（默认只捕获 preprocessing）
      if (opts.captureDir.isNotEmpty &&
          status == 200 &&
          step.startsWith(opts.captureStep) &&
          captureCount < opts.captureLimit) {
        captureCount++;
        final dir = Directory(opts.captureDir);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final base = '${opts.captureDir}/'
            '${captureCount.toString().padLeft(3, '0')}_${step.replaceAll(':', '-')}';
        try {
          File('$base.req.json').writeAsStringSync(bodyText);
          File('$base.resp.json')
              .writeAsStringSync(utf8.decode(responseBytes, allowMalformed: true));
        } catch (_) {
          // 捕获失败不影响转发
        }
      }

      final flag = status >= 400 ? ' ERR' : '';
      stdout.writeln(
        '[$totalCalls] ${step.padRight(20)} '
        'in=${usageIn.toString().padLeft(6)} '
        'out=${usageOut.toString().padLeft(6)} '
        '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s$flag'
        '${errorNote != null ? '  $errorNote' : ''}',
      );

      if (opts.echo) {
        _echoModelOutput(step, parsedJson, responseBytes, opts.echoLimit);
      }

      try {
        request.response.statusCode = status == 599 ? 502 : status;
        responseHeaders.forEach((name, values) {
          for (final value in values) {
            request.response.headers.add(name, value);
          }
        });
        request.response.headers.contentLength = responseBytes.length;
        request.response.add(responseBytes);
      } catch (_) {
        // 客户端可能已断开（如取消对局），忽略
      } finally {
        try {
          await request.response.close();
        } catch (_) {
          // 同上
        }
      }
    }());
  }
}

/// 把模型的真实输出打到终端。
///
/// chat completions 取 `choices[0].message.content`；System One / decisions
/// 没有 content 字段，回显整个 `answers` 对象。
void _echoModelOutput(String step, Object? json, List<int> rawBytes, int limit) {
  String content;
  if (json is Map) {
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final message = (choices.first as Map)['message'];
      if (message is Map && message['content'] is String) {
        content = message['content'] as String;
      } else {
        content = const JsonEncoder.withIndent('  ').convert(choices.first);
      }
    } else if (json['answers'] != null) {
      content = const JsonEncoder.withIndent('  ').convert(json['answers']);
    } else if (json['error'] != null) {
      content = '错误: ${json['error']}';
    } else {
      content = const JsonEncoder.withIndent('  ').convert(json);
    }
  } else {
    content = utf8.decode(rawBytes, allowMalformed: true);
  }

  final shown = limit > 0 && content.length > limit
      ? '${content.substring(0, limit)}'
          '…(已截断，完整 ${content.length} 字符；--capture 目录里有原文)'
      : content;

  stdout.writeln('----- $step 模型输出 -----');
  for (final line in shown.split('\n')) {
    stdout.writeln('  | $line');
  }
  stdout.writeln('-------------------------');
}

void _printSummary(
  int calls,
  int inputTokens,
  int outputTokens,
  int missing,
  Map<String, int> perStep,
) {
  stdout.writeln('\n=== 汇总 ===');
  stdout.writeln('调用数      $calls');
  stdout.writeln('输入 token  $inputTokens');
  stdout.writeln('输出 token  $outputTokens');
  if (missing > 0) {
    stdout.writeln('缺少 usage  $missing（成本会被低估）');
  }
  final entries = perStep.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in entries) {
    stdout.writeln('  ${entry.key.padRight(20)} ${entry.value} 次');
  }
  stdout.writeln('成本报表：dart tool/cost_report.dart');
}
