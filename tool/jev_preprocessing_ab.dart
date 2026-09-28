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
    required this.historyChars,
    required this.hasPublicSpeech,
    required this.day,
    required this.phase,
    required this.selfRole,
    required this.selfNumber,
    required this.teammates,
  });

  final String file;
  final String state;
  final Map<String, String> generativeRoles;
  final Map<String, int> generativeConfidences;
  final int generativeRawLength;
  final bool generativeJsonOk;

  /// `**游戏历史**` 段落的字符数，仅用于展示。
  final int historyChars;

  /// 历史里是否出现过**公开发言**。这才是"这批样本有没有判定基础"的判据。
  ///
  /// 刻意不用字符数：狼人视角的第 1 夜历史可能很长（含狼队会议原文），
  /// 但对"谁是狼"没有任何公开信息——狼只看得见自己人。
  final bool hasPublicSpeech;

  /// 从提示词抄下来的自述信息，用于干跑时核对，以及推断真值狼队。
  final String day;
  final String phase;
  final String selfRole;

  /// 该样本视角玩家自己的号码（"2号玩家" -> "2"）。
  final String selfNumber;
  final List<String> teammates;
}

class _Options {
  _Options({
    required this.dir,
    required this.wolves,
    required this.base,
    required this.model,
    required this.configPath,
    required this.limit,
    required this.dryRun,
  });

  final String dir;

  /// 真值狼队。留空时从样本里推断（狼人样本自述了角色与全部队友）。
  final Set<String> wolves;
  final String base;
  final String model;
  final String configPath;
  final int limit;

  /// 只体检样本、不调用任何模型（因此也不产生费用）。
  final bool dryRun;
}

_Options _parseArgs(List<String> args) {
  var dir = '/tmp/wwtest/samples2';
  var wolves = <String>{};
  var base = _defaultBase;
  var model = _defaultModel;
  var configPath = 'werewolf_config.yaml';
  var limit = 12;
  var dryRun = false;

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
      case '--dry-run':
        dryRun = true;
      case '--help':
      case '-h':
        stdout.writeln(
          'dart tool/jev_preprocessing_ab.dart [--wolves 1,6,10,12] [--dir DIR]\n'
          '    [--limit N] [--base URL] [--model ID] [--config f] [--dry-run]\n'
          '\n'
          '  --wolves   真值狼队。省略时从样本推断（狼人样本自述了角色与全部队友）。\n'
          '  --dry-run  只打印样本体检（天数/阶段/有无公开发言）与推断出的真值，\n'
          '             不调用任何模型，因此不产生费用。',
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
    dryRun: dryRun,
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

/// 取 `**游戏历史**` 段的字符数（仅用于展示）。
int _historyChars(String state) {
  final start = state.indexOf('**游戏历史**');
  if (start < 0) return 0;
  var end = state.indexOf('\n**', start + 12);
  if (end < 0) end = state.indexOf('\n---', start);
  if (end < 0) end = state.length;
  return state.substring(start, end).trim().length;
}

/// 历史里是否出现过**公开发言**——这是"这批样本有没有判定基础"的判据。
///
/// 不能用字符数代替：狼人视角的第 1 夜历史可以很长（含狼队会议原文），
/// 但对"谁是狼"没有公开信息。夜间只有狼队内部发言，必须排除。
bool _hasPublicSpeech(String state) {
  for (final raw in state.split('\n')) {
    final line = raw.trim();
    if (line.contains('狼人讨论环节')) continue;
    if (line.contains('的竞选发言')) return true;
    if (line.contains('发表遗言')) return true;
    if (RegExp(r'天，\d+号玩家：').hasMatch(line)) return true;
  }
  return false;
}

/// 取提示词里 `- 标签: 值` 形式的一行。
String _lineValue(String state, String label) {
  final m = RegExp('- ${RegExp.escape(label)}: (.+)').firstMatch(state);
  return m == null ? '' : m.group(1)!.trim();
}

String _dayOf(String state) {
  final m = RegExp(r'- 第(\d+)天').firstMatch(state);
  return m == null ? '?' : m.group(1)!;
}

/// "3号玩家" -> "3"。
String _numberOnly(String name) =>
    name.trim().replaceAll('号玩家', '').replaceAll('号', '');

/// 真值狼队直接从样本推：狼人样本自述了角色，并列出了全部队友，
/// 再加上自己——只统计队友会漏掉该样本视角的玩家本人。
///
/// 手工填这一步最容易出错，而填错会让整轮对比作废——所以能推就推。
Set<String> _inferWolves(List<_Sample> samples) {
  final wolves = <String>{};
  for (final s in samples) {
    if (s.selfRole != '狼人') continue;
    if (s.selfNumber.isNotEmpty) wolves.add(s.selfNumber);
    wolves.addAll(s.teammates.map(_numberOnly));
  }
  return wolves..removeWhere((w) => w.isEmpty);
}

/// 按号码数值排序（字典序会把 10、12 排到 2 前面）。
List<String> _sortedByNumber(Iterable<String> ids) {
  final list = ids.toList();
  list.sort((a, b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  });
  return list;
}

/// 把"这批样本有没有判定基础"讲清楚。
///
/// 原版是写死一句"样本全来自第 1 夜"；实际上取决于样本本身，
/// 所以要按批评估，而不是无条件声明。
void _printBasisWarning(int informative, int total) {
  if (informative == 0) {
    stdout.writeln(
      '\n!! 本次对比没有判定基础：$total 个样本的历史里都没有公开发言。\n'
      '   命中率差异只反映"信息不足时如何兜底"，不构成质量结论；\n'
      '   这组数字只能用于比较成本 / 延迟 / 输出体量。',
    );
  } else if (informative < total) {
    stdout.writeln(
      '\n注意：仅 $informative/$total 个样本有公开发言，'
      '其余样本无判定基础，会把两边的差异往"都靠基础概率"拉平。',
    );
  }
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

    final state = _stateFromUserPrompt(userPrompt);
    final teammates = _lineValue(state, '队友');

    samples.add(
      _Sample(
        file: req.uri.pathSegments.last,
        state: state,
        generativeRoles: roles,
        generativeConfidences: confidences,
        generativeRawLength: content.length,
        generativeJsonOk: jsonOk,
        historyChars: _historyChars(state),
        hasPublicSpeech: _hasPublicSpeech(state),
        day: _dayOf(state),
        phase: _lineValue(state, '当前阶段'),
        selfRole: _lineValue(state, '角色'),
        selfNumber: _numberOnly(_lineValue(state, '号码')),
        teammates: teammates.isEmpty
            ? const []
            : teammates.split(',').map((s) => s.trim()).toList(),
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

  // 先读样本再定真值：真值可以从狼人样本的自述里推出来。
  final samples = _loadSamples(opts);
  if (samples.isEmpty) {
    stderr.writeln('没有可用样本');
    exit(2);
  }

  final wolves = opts.wolves.isNotEmpty ? opts.wolves : _inferWolves(samples);
  if (wolves.isEmpty) {
    stderr.writeln(
      '推不出真值狼队：样本里没有狼人视角的提示词（队友字段是唯一线索）。\n'
      '请用 --wolves 1,6,10,12 手工给，或换一个样本目录。',
    );
    exit(2);
  }
  final wolvesSorted = _sortedByNumber(wolves);
  final informative = samples.where((s) => s.hasPublicSpeech).length;

  if (opts.dryRun) {
    stdout.writeln('=== 干跑：不调用任何模型，不产生费用 ===');
    stdout.writeln('样本目录 ${opts.dir}   共 ${samples.length} 个');
    stdout.writeln(
      '真值狼队 ${wolvesSorted.join(',')}'
      '（${opts.wolves.isEmpty ? '由样本推断' : '由 --wolves 指定'}）',
    );
    stdout.writeln('有公开发言的样本 $informative / ${samples.length}\n');
    for (final s in samples) {
      stdout.writeln(
        '${s.file.substring(0, 3)}  第${s.day}天 ${s.phase}  '
        '自述=${s.selfRole}  历史${s.historyChars}字符'
        '${s.hasPublicSpeech ? '' : '  <- 无公开发言，无判定基础'}',
      );
    }
    _printBasisWarning(informative, samples.length);
    return;
  }

  final key = _configValue(opts.configPath, 'default_llm', 'api_key') ??
      Platform.environment['OPENAI_API_KEY'] ??
      '';
  if (key.isEmpty) {
    stderr.writeln('缺少 key（${opts.configPath} 的 default_llm.api_key）');
    exit(2);
  }

  final allPlayers = List.generate(12, (i) => '${i + 1}');
  stdout.writeln(
    '样本 ${samples.length} 个（有公开发言 $informative 个）   '
    '真值狼队: ${wolvesSorted.join(',')}',
  );
  stdout.writeln('模型 ${opts.model}   端点 ${opts.base}/v1/systemone\n');
  _printBasisWarning(informative, samples.length);

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

    genHits += genFlagged.intersection(wolves).length;
    genFalsePos += genFlagged.difference(wolves).length;
    jevHits += jevFlagged.intersection(wolves).length;
    jevFalsePos += jevFlagged.difference(wolves).length;

    final sorted = result.wolves.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).map((e) {
      final id = e.key.replaceAll('p', '').replaceAll('_wolf', '');
      final mark = wolves.contains(id) ? '*' : ' ';
      return '$id$mark=${e.value.toStringAsFixed(2)}';
    }).join(' ');

    stdout.writeln(
      '${sample.file.substring(0, 3)}  '
      '生成版标记: ${genFlagged.isEmpty ? '无' : genFlagged.join(',')}  '
      '| Jev 前三: $top3  '
      '| ${result.latencyMs}ms \$${result.cost.toStringAsFixed(6)}',
    );
  }

  final wolfCount = wolves.length;
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
  // 是否具备判定基础由 _printBasisWarning 按样本实际情况给出，
  // 不再无条件声明"这些样本全部来自第 1 夜"。
}
