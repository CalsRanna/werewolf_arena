// 预处理阶段 A/B：把捕获的真实调用样本，与 Jev 版本逐字段对比。
//
// 背景（读代码得到的事实）：
//   PreprocessingStage 用一次生成调用产出 WorldState JSON，字段分三类：
//     1) 事实回显：self_info(name/number/role/faction/teammates/secret_knowledge)
//        —— 这些在输入里已经原样给出，属于让模型抄写
//     2) 受限判定：other_players[].estimated_role / estimated_confidence、
//        social_relationships.alliances / hostilities —— 答案空间可枚举
//     3) 自由文本：key_speech_summary、key_events[].description、
//        situation_summary、core_conflict —— Jev 不生成文本
//   下游只有 core_cognition 消费它（整个 JSON 塞进提示词），不喂代码逻辑。
//
// 因此本脚本只对比第 2 类里**有客观真值**的那一项：谁是真狼人。
// 真值来自上帝视角日志里狼人战术会议的发言者（狼队全员都会发言）。
//
// 用法：
//   dart tool/jev_preprocessing_ab.dart --wolves 1,2,7,12
//   dart tool/jev_preprocessing_ab.dart --wolves 1,2,7,12 --dir /tmp/wwtest/samples2

import 'dart:convert';
import 'dart:io';

const String _defaultBase = 'https://openrouter.ai/api';
const String _defaultModel = 'typesafe/jev-1.13';

class _Sample {
  _Sample({
    required this.file,
    required this.state,
    required this.generativeRoles,
    required this.generativeConfidences,
    required this.generativeRawLength,
    required this.generativeJsonOk,
  });

  final String file;
  final String state;
  final Map<String, String> generativeRoles;
  final Map<String, int> generativeConfidences;
  final int generativeRawLength;
  final bool generativeJsonOk;
}

class _Options {
  _Options({
    required this.dir,
    required this.wolves,
    required this.base,
    required this.model,
    required this.configPath,
    required this.limit,
  });

  final String dir;
  final Set<String> wolves;
  final String base;
  final String model;
  final String configPath;
  final int limit;
}

_Options _parseArgs(List<String> args) {
  var dir = '/tmp/wwtest/samples2';
  var wolves = <String>{};
  var base = _defaultBase;
  var model = _defaultModel;
  var configPath = 'werewolf_config.yaml';
  var limit = 12;

  for (var i = 0; i < args.length; i++) {
    String? next() => i + 1 < args.length ? args[++i] : null;
    switch (args[i]) {
      case '--dir':
        dir = next() ?? dir;
      case '--wolves':
        wolves = (next() ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
      case '--base':
        base = next() ?? base;
      case '--model':
        model = next() ?? model;
      case '--config':
        configPath = next() ?? configPath;
      case '--limit':
        limit = int.tryParse(next() ?? '') ?? limit;
      case '--help':
      case '-h':
        stdout.writeln(
          'dart tool/jev_preprocessing_ab.dart --wolves 1,2,7,12 '
          '[--dir DIR] [--limit N] [--base URL] [--model ID] [--config f]',
        );
        exit(0);
    }
  }
  return _Options(
    dir: dir,
    wolves: wolves,
    base: base,
    model: model,
    configPath: configPath,
    limit: limit,
  );
}

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
    if (value.contains('在这里填') || value == 'YOUR_KEY_HERE') return null;
    return value;
  }
  return null;
}

/// 从捕获的请求体里取出可用作 Jev state 的部分。
/// 去掉"请整理成以下 JSON"那段任务说明——那是给生成模型的格式要求，
/// 对判定没有信息量，留着只会稀释 state（Jev 对无关内容敏感）。
String _stateFromUserPrompt(String userPrompt) {
  final cut = userPrompt.indexOf('# 任务');
  final body = cut > 0 ? userPrompt.substring(0, cut) : userPrompt;
  return body.trim();
}

List<_Sample> _loadSamples(_Options opts) {
  final dir = Directory(opts.dir);
  if (!dir.existsSync()) {
    stderr.writeln('样本目录不存在：${opts.dir}');
    exit(2);
  }
  final reqs = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.req.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final samples = <_Sample>[];
  for (final req in reqs.take(opts.limit)) {
    final respPath = req.path.replaceAll('.req.json', '.resp.json');
    final respFile = File(respPath);
    if (!respFile.existsSync()) continue;

    final reqJson = jsonDecode(req.readAsStringSync()) as Map<String, dynamic>;
    final messages = reqJson['messages'] as List;
    final userPrompt = (messages[1] as Map)['content'] as String;

    final respJson =
        jsonDecode(respFile.readAsStringSync()) as Map<String, dynamic>;
    final content =
        ((respJson['choices'] as List).first as Map)['message']['content']
            as String;

    final roles = <String, String>{};
    final confidences = <String, int>{};
    var jsonOk = false;
    try {
      final cleaned = content.trim().replaceAll('```json', '').replaceAll('```', '');
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      for (final raw in (data['other_players'] as List? ?? const [])) {
        final p = raw as Map;
        final name = (p['name'] as String? ?? '').replaceAll('号玩家', '');
        roles[name] = (p['estimated_role'] as String?) ?? '';
        confidences[name] = (p['estimated_confidence'] as num?)?.toInt() ?? 0;
      }
      jsonOk = true;
    } catch (_) {
      jsonOk = false;
    }

    samples.add(
      _Sample(
        file: req.uri.pathSegments.last,
        state: _stateFromUserPrompt(userPrompt),
        generativeRoles: roles,
        generativeConfidences: confidences,
        generativeRawLength: content.length,
        generativeJsonOk: jsonOk,
      ),
    );
  }
  return samples;
}

Future<({Map<String, double> wolves, int inputTokens, int outputTokens, double cost, int latencyMs})>
    _callJev(String state, List<String> players, _Options opts, String key) async {
  final questions = <String, Object?>{
    for (final id in players)
      'p${id}_wolf': {
        'type': 'noul',
        'instructions':
            '$id 号玩家是狼人的概率有多高？只依据 state 中的公开信息判断；'
            '若几乎没有可用信息，给出接近基础概率的低值，不要编造依据。',
      },
  };
  final body = jsonEncode({
    'model': opts.model,
    'state': state,
    'questions': questions,
  });

  final client = HttpClient();
  final stopwatch = Stopwatch()..start();
  try {
    final request = await client.postUrl(
      Uri.parse('${opts.base}/v1/systemone'),
    );
    request.headers.set('Authorization', 'Bearer $key');
    request.headers.contentType = ContentType.json;
    final bytes = utf8.encode(body);
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close().timeout(const Duration(seconds: 120));
    final text = await response.transform(utf8.decoder).join();
    stopwatch.stop();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: ${text.substring(0, text.length.clamp(0, 300))}');
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final usage = json['usage'] as Map?;
    final answers = json['answers'] as Map;
    final wolves = <String, double>{};
    for (final entry in answers.entries) {
      final key = entry.key.toString();
      final value = entry.value as Map;
      if (value['type'] == 'noul') {
        wolves[key] =
            (value['noul'] as num?)?.toDouble() ?? 0;
      }
    }
    return (
      wolves: wolves,
      inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
      cost: (usage?['cost'] as num?)?.toDouble() ?? 0,
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  if (opts.wolves.isEmpty) {
    stderr.writeln('必须给真值：--wolves 1,2,7,12（取上帝视角日志里狼人战术会议的发言者）');
    exit(2);
  }
  final key = _configValue(opts.configPath, 'default_llm', 'api_key') ??
      Platform.environment['OPENAI_API_KEY'] ??
      '';
  if (key.isEmpty) {
    stderr.writeln('缺少 key（${opts.configPath} 的 default_llm.api_key）');
    exit(2);
  }

  final samples = _loadSamples(opts);
  if (samples.isEmpty) {
    stderr.writeln('没有可用样本');
    exit(2);
  }

  final allPlayers = List.generate(12, (i) => '${i + 1}');
  stdout.writeln('样本 ${samples.length} 个   真值狼队: ${opts.wolves.join(',')}');
  stdout.writeln('模型 ${opts.model}   端点 ${opts.base}/v1/systemone\n');

  // 聚合指标
  var genHits = 0; // 生成版指出来的真狼数
  var genFalsePos = 0; // 生成版指错的好人数
  var genLabelled = 0; // 生成版给出非"未知"判断的人数
  var jevHits = 0;
  var jevFalsePos = 0;
  var jevInputTokens = 0;
  var jevCost = 0.0;
  final jevLatencies = <int>[];
  final genCosts = <double>[];
  var genOutputChars = 0;

  for (final sample in samples) {
    final result = await _callJev(sample.state, allPlayers, opts, key);
    jevInputTokens += result.inputTokens;
    jevCost += result.cost;
    jevLatencies.add(result.latencyMs);
    genOutputChars += sample.generativeRawLength;

    // 生成版：低置信度的"未知"不算判断
    final genFlagged = <String>{};
    for (final entry in sample.generativeRoles.entries) {
      final conf = sample.generativeConfidences[entry.key] ?? 0;
      if (entry.value == '狼人' && conf >= 50) genFlagged.add(entry.key);
    }
    genLabelled += sample.generativeRoles.values
        .where((r) => r.isNotEmpty && r != '未知')
        .length;

    // Jev：阈值 0.5
    final jevFlagged = <String>{
      for (final entry in result.wolves.entries)
        if (entry.value >= 0.5)
          entry.key.replaceAll('p', '').replaceAll('_wolf', ''),
    };

    genHits += genFlagged.intersection(opts.wolves).length;
    genFalsePos += genFlagged.difference(opts.wolves).length;
    jevHits += jevFlagged.intersection(opts.wolves).length;
    jevFalsePos += jevFlagged.difference(opts.wolves).length;

    final sorted = result.wolves.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).map((e) {
      final id = e.key.replaceAll('p', '').replaceAll('_wolf', '');
      final mark = opts.wolves.contains(id) ? '*' : ' ';
      return '$id$mark=${e.value.toStringAsFixed(2)}';
    }).join(' ');

    stdout.writeln(
      '${sample.file.substring(0, 3)}  '
      '生成版标记: ${genFlagged.isEmpty ? '无' : genFlagged.join(',')}  '
      '| Jev 前三: $top3  '
      '| ${result.latencyMs}ms \$${result.cost.toStringAsFixed(6)}',
    );
  }

  final wolfCount = opts.wolves.length;
  final goodCount = 12 - wolfCount;
  stdout.writeln('\n=== 汇总（${samples.length} 个样本，真狼 $wolfCount 人 / 好人 $goodCount 人）===');
  stdout.writeln('生成版预处理：');
  stdout.writeln(
    '  命中真狼 ${genHits}/${wolfCount * samples.length}   '
    '误报好人 ${genFalsePos}   给出非"未知"判断 ${genLabelled} 条',
  );
  stdout.writeln('  JSON 解析失败样本: ${samples.where((s) => !s.generativeJsonOk).length}');
  stdout.writeln('  输出总字符 ${genOutputChars}（平均 ${(genOutputChars / samples.length).round()}）');
  stdout.writeln('Jev 版：');
  stdout.writeln(
    '  命中真狼 ${jevHits}/${wolfCount * samples.length}   '
    '误报好人 ${jevFalsePos}',
  );
  jevLatencies.sort();
  stdout.writeln(
    '  延迟中位 ${jevLatencies[jevLatencies.length ~/ 2]}ms   '
    '输入共 $jevInputTokens tokens   成本 \$${jevCost.toStringAsFixed(6)}',
  );
  stdout.writeln(
    '  折合单次 输入 ${(jevInputTokens / samples.length).round()} tokens，'
    '\$${(jevCost / samples.length).toStringAsFixed(6)}',
  );
  stdout.writeln(
    '\n说明：这些捕获样本全部来自第 1 夜（游戏历史为空），'
    '两种方法都没有可用信息，因此命中率都在基础概率附近——'
    '本对比能说明的是成本/延迟/输出体量，不能说明"有信息时谁更准"。',
  );
}
