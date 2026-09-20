// Jev（System One）探针：按官方规格直接调用决策接口，测量延迟/成本/中文判定质量。
//
// 关键事实（来自 OpenRouter 官方文档与端点元数据）：
//   - Jev 不能走 /chat/completions："is a decisions model and cannot be used
//     with the chat/completions endpoint"
//   - 正确端点是 POST {base}/v1/systemone（OpenRouter 上 base=https://openrouter.ai/api，
//     也是 /api/alpha/decisions 的别名）
//   - 请求体 {model, state, questions}，questions 里每个问题是 noul / choice / score
//   - 响应 {id, model, provider, answers, usage:{input_tokens, output_tokens, cost}}
//   - 模态 text->decisions，supported_parameters 为空，所以不要带 temperature 等参数
//
// 用法：
//   export OPENAI_API_KEY=sk-or-...            # 复用 OpenRouter 的 key
//   dart tool/jev_probe.dart                   # 跑内置的 12 人狼人杀样例
//   dart tool/jev_probe.dart --base https://api.typesafe.ai   # 直连 TypeSafe
//   dart tool/jev_probe.dart --base http://127.0.0.1:8787     # 经本地代理（可入账）
//   dart tool/jev_probe.dart --model typesafe/jev-1.13

import 'dart:convert';
import 'dart:io';

const String _defaultBase = 'https://openrouter.ai/api';
const String _defaultModel = 'jev-1.13';

class _Options {
  _Options({
    required this.base,
    required this.model,
    required this.repeat,
    required this.state,
    required this.questions,
    required this.raw,
    required this.configPath,
    required this.keyOverride,
  });

  final String base;
  final String model;
  final int repeat;
  final String state;
  final Map<String, Object?> questions;
  final bool raw;

  /// 配置文件路径：密钥与 System One 的 base/model 都从这里读。
  final String configPath;

  /// 命令行覆盖的密钥（优先级最高）。
  final String? keyOverride;
}

_Options _parseArgs(List<String> args) {
  var base = _defaultBase;
  var model = _defaultModel;
  var repeat = 1;
  var raw = false;
  var configPath = 'werewolf_config.yaml';
  String? keyOverride;
  var baseFromCli = false;
  var modelFromCli = false;
  var state = _sampleState;
  Map<String, Object?> questions = _sampleQuestions();

  for (var i = 0; i < args.length; i++) {
    String? next() => i + 1 < args.length ? args[++i] : null;
    switch (args[i]) {
      case '--config':
        configPath = next() ?? configPath;
      case '--key':
        keyOverride = next();
      case '--base':
        base = next() ?? base;
        baseFromCli = true;
      case '--model':
        model = next() ?? model;
        modelFromCli = true;
      case '--raw':
        raw = true;
      case '--repeat':
        repeat = int.tryParse(next() ?? '') ?? repeat;
      case '--state-file':
        final path = next();
        if (path != null) state = File(path).readAsStringSync();
      case '--questions-file':
        final path = next();
        if (path != null) {
          questions =
              jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
        }
      case '--help':
      case '-h':
        stdout.writeln(
          'dart tool/jev_probe.dart [--base URL] [--model ID] [--repeat N] '
          '[--config f] [--key K] [--state-file f] [--questions-file f] [--raw]',
        );
        exit(0);
    }
  }
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (!baseFromCli) {
    base = _configValue(configPath, 'systemone', 'base_url') ?? base;
  }
  if (!modelFromCli) {
    model = _configValue(configPath, 'systemone', 'model') ?? model;
  }
  return _Options(
    base: base,
    model: model,
    repeat: repeat,
    state: state,
    questions: questions,
    raw: raw,
    configPath: configPath,
    keyOverride: keyOverride,
  );
}

/// 极简 YAML 取值：只认"顶级段 + 二级标量键"这一种形状（即本项目配置文件）。
/// 不是通用 YAML 解析器——需要列表或更深嵌套就上 package:yaml。
String? _configValue(String path, String section, String key) {
  final file = File(path);
  if (!file.existsSync()) return null;
  var inSection = false;
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final indented = line.startsWith(' ') || line.startsWith('\t');
    if (!indented) {
      inSection = line.trimLeft().startsWith('$section:');
      continue;
    }
    if (!inSection) continue;
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('$key:')) continue;
    var value = trimmed.substring(key.length + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    if (value.isEmpty) return null;
    // 占位符视为未配置
    if (value.contains('在这里填') || value == 'YOUR_KEY_HERE') return null;
    return value;
  }
  return null;
}

/// 密钥优先级：--key > 配置文件 > 环境变量（环境变量仅作兜底）。
String _resolveApiKey(_Options opts) {
  if (opts.keyOverride != null && opts.keyOverride!.isNotEmpty) {
    return opts.keyOverride!;
  }
  final fromConfig = _configValue(opts.configPath, 'default_llm', 'api_key');
  if (fromConfig != null) return fromConfig;
  return Platform.environment['OPENAI_API_KEY'] ??
      Platform.environment['OPENROUTER_API_KEY'] ??
      Platform.environment['TYPESAFE_API_KEY'] ??
      '';
}

/// 一段贴近真实对局的白天状态：12 人，已发生预言家跳身份与两轮发言。
const String _sampleState = '''
【对局】12 人标准局，第 2 个白天。昨夜 11 号被杀。
存活：1、2、3、4、5、6、7、8、9、10、12 号（共 11 人，其中狼人 3 名仍在场）。
已出局：11 号（昨夜）、13 号（第 1 天投票出局，后确认是村民）。

【第 1 天发言摘要】
4 号：我是预言家。第 1 晚验了 8 号，是好人。我建议今天先票 13 号。
8 号：我确实是好人。4 号召警长，我支持，但我保留他是不是真预言家的判断。
2 号：4 号跳得比较早，但 13 号的发言也不算太可疑，暂时不站边。
6 号：我怀疑 4 号是悍跳。他说验了 8 号是好人，这和 8 号后面的发言对不上，像是提前商量好的。
9 号：我是村民。我觉得 6 号太急了，第一天就要打 4 号，像狼在找预言家。
5 号：没有特别的信息，跟票。
3 号：我信 4 号。6 号的逻辑很奇怪。
10 号：我保持中立，想再听听 4 号验人。
12 号：我是女巫，昨夜我救了 11 号，但他还是死了。我没用药。

【第 2 天发言摘要】
6 号：我还是坚持 4 号是悍跳。如果 4 号是真预言家，今晚应该验出结果了。
8 号：我是好人，4 号第一晚验我的事我确认过。但 4 号今天的验人结果还没说。
9 号：我还是觉得 6 号有问题。
7 号：我一直在跟，没有信息，你们决定。
1 号：我怀疑 12 号的女巫身份，救 11 号却还是死了，这个说法可以随便编。
''';

/// 问题集：逐个玩家一个 noul（高基数、逐对判定）+ 一个投票 choice。
Map<String, Object?> _sampleQuestions() {
  const alive = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '12'];
  return {
    for (final id in alive)
      'p${id}_wolf': {
        'type': 'noul',
        'instructions': '$id 号是狼人的概率有多高？只依据 state 里出现的发言与事实判断。',
      },
    'vote_today': {
      'type': 'choice',
      'instructions': '今天白天最应该投票淘汰谁？',
      'criteria': {
        for (final id in alive) id: '$id 号的发言最可疑',
      },
    },
    'seer_credibility': {
      'type': 'choice',
      'instructions': '4 号声称自己是预言家，可信度如何？',
      'criteria': {
        'high': '基本可信，有具体验人信息且逻辑自洽',
        'medium': '说不清，证据不足',
        'low': '很可能在悍跳',
      },
    },
  };
}

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final key = _resolveApiKey(opts);
  if (key.isEmpty) {
    stderr.writeln(
      '缺少 API key：请在 ${opts.configPath} 的 default_llm.api_key 中填入，'
      '或用 --key 传入。',
    );
    exit(2);
  }

  final uri = Uri.parse('${opts.base}/v1/systemone');
  final body = jsonEncode({
    'model': opts.model,
    'state': opts.state,
    'questions': opts.questions,
  });

  stdout.writeln('端点      $uri');
  stdout.writeln('模型      ${opts.model}');
  stdout.writeln(
    '问题数    ${opts.questions.length}'
    '（noul ${opts.questions.values.where((q) => (q as Map)['type'] == 'noul').length} 个，'
    'choice ${opts.questions.values.where((q) => (q as Map)['type'] == 'choice').length} 个）',
  );
  stdout.writeln('state 长度 ${opts.state.length} 字符');
  stdout.writeln('');

  final client = HttpClient();
  final latencies = <int>[];
  var totalInput = 0;
  var totalOutput = 0;
  var totalCost = 0.0;

  for (var run = 1; run <= opts.repeat; run++) {
    final stopwatch = Stopwatch()..start();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $key');
      request.headers.contentType = ContentType.json;
      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(
        const Duration(seconds: 120),
      );
      final text = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      if (response.statusCode != 200) {
        stdout.writeln('HTTP ${response.statusCode}');
        stdout.writeln(text.length > 800 ? text.substring(0, 800) : text);
        if (response.statusCode == 404) {
          stdout.writeln(
            '\n提示：404 通常是端点或模型 id 不对。Jev 不能走 /chat/completions，'
            '必须用 /v1/systemone。',
          );
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          stdout.writeln('\n提示：鉴权失败，检查 key 是否为 OpenRouter key。');
        }
        exit(1);
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final usage = json['usage'] as Map?;
      final inputTokens = (usage?['input_tokens'] as num?)?.toInt() ?? 0;
      final outputTokens = (usage?['output_tokens'] as num?)?.toInt() ?? 0;
      final cost = (usage?['cost'] as num?)?.toDouble() ?? 0;
      totalInput += inputTokens;
      totalOutput += outputTokens;
      totalCost += cost;
      latencies.add(stopwatch.elapsedMilliseconds);

      stdout.writeln('--- 第 $run 次 ---');
      stdout.writeln(
        '模型回执  ${json['model']}   厂商 ${json['provider']}',
      );
      stdout.writeln(
        '耗时      ${stopwatch.elapsedMilliseconds}ms   '
        '输入 $inputTokens tokens  输出 $outputTokens tokens  成本 \$$cost',
      );
      if (opts.raw) {
        // 首次真实调用务必看原始响应：字段名以实际返回为准，不要依赖猜测
        const encoder = JsonEncoder.withIndent('  ');
        stdout.writeln(encoder.convert(json));
      } else {
        _printAnswers(json['answers']);
      }
    } catch (error) {
      stopwatch.stop();
      stdout.writeln('请求失败：$error');
      exit(1);
    }
  }

  latencies.sort();
  stdout.writeln('\n=== 汇总 ===');
  stdout.writeln(
    '调用 ${opts.repeat} 次  输入 $totalInput tokens  输出 $totalOutput tokens  '
    '合计成本 \$${totalCost.toStringAsFixed(6)}',
  );
  if (latencies.isNotEmpty) {
    stdout.writeln(
      '延迟 最小 ${latencies.first}ms  中位 ${latencies[latencies.length ~/ 2]}ms  '
      '最大 ${latencies.last}ms',
    );
  }
  final perCall = totalInput / opts.repeat;
  stdout.writeln(
    '折合单次：输入 ${perCall.toStringAsFixed(0)} tokens，'
    '按 \$0.042/MTok 约 \$${(perCall / 1000000 * 0.042).toStringAsFixed(8)}',
  );
  client.close();
}

void _printAnswers(Object? answers) {
  if (answers is! Map) {
    stdout.writeln('answers 字段缺失或格式异常：$answers');
    return;
  }
  final nouls = <MapEntry<String, double>>[];
  final choices = <String, List<MapEntry<String, double>>>{};
  for (final entry in answers.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final type = value['type'];
    if (type == 'noul') {
      nouls.add(
        MapEntry(entry.key.toString(), (value['noul'] as num?)?.toDouble() ?? 0),
      );
    } else if (type == 'choice') {
      final probabilities = value['probabilities'];
      final items = <MapEntry<String, double>>[];
      if (probabilities is Map) {
        for (final p in probabilities.entries) {
          items.add(
            MapEntry(
              p.key.toString(),
              (p.value as num?)?.toDouble() ?? 0,
            ),
          );
        }
        items.sort((a, b) => b.value.compareTo(a.value));
      }
      choices[entry.key.toString()] = items;
    } else {
      stdout.writeln('  ${entry.key}: $value');
    }
  }

  if (nouls.isNotEmpty) {
    nouls.sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln('  逐人判定（概率从高到低）：');
    for (final noul in nouls) {
      final bar = '#' * (noul.value * 20).round();
      stdout.writeln(
        '    ${noul.key.padRight(12)} ${noul.value.toStringAsFixed(3)} $bar',
      );
    }
  }
  for (final choice in choices.entries) {
    stdout.writeln('  ${choice.key}：');
    for (final item in choice.value) {
      stdout.writeln(
        '    ${item.key.padRight(12)} ${item.value.toStringAsFixed(3)}',
      );
    }
  }
}
