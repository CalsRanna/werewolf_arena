// 成本报表：读 tool/llm_proxy_recorder.dart 产出的 JSONL，算现价成本，
// 再算"把某些步骤换成 Jev"之后的反事实成本。
//
// 无第三方依赖（只用 dart:io / dart:convert）：
//
//   dart tool/cost_report.dart                  # 默认读 tool/llm_calls.jsonl
//   dart tool/cost_report.dart --log xxx.jsonl
//   dart tool/cost_report.dart check            # 用你的 key 问 OpenRouter 有没有 jev
//
// 价格单位：美元 / 百万 token（MTok）。

import 'dart:convert';
import 'dart:io';

/// 默认价格：DeepSeek V4.1 Flash 取自 OpenRouter 公开清单（prompt 0.15 / completion 0.60）；
/// Jev 取自 TypeSafe 官方文档（输入 $0.042/MTok，输出免费）。
const double _defaultLlmIn = 0.15;
const double _defaultLlmOut = 0.60;
const double _defaultJevIn = 0.042;
const double _defaultJevOut = 0.0;

/// 可替换成 Jev 的步骤预设。含义见 README/对话：判定型步骤可换，生成型不能换。
const Map<String, List<String>> _presets = {
  // ── 适配本项目默认的 staged 引擎（每玩家回合 3 次调用）──
  //
  // 纯判定/抽取类：答案空间可事前枚举，Jev 的 Choice/Noul 直接对应。
  // 其中 preprocessing 是"把游戏信息整理成结构化 JSON"，属抽取；
  // postprocessing 是"检查发言是否泄露秘密"，属一致性判定；
  // 各 skill:xxx 都是"选一个目标玩家/是否用药"这类受限选择。
  'staged-judgment': [
    'stage:preprocessing',
    'stage:postprocessing',
    'skill:protect',
    'skill:kill',
    'skill:heal',
    'skill:poison',
    'skill:investigate',
    'skill:transfer_badge',
    'skill:vote',
    'skill:sheriff_vote',
    'skill:shoot',
    'skill:campaign',
    'skill:withdraw',
  ],
  // 更保守：只换两个 staged 阶段，不动角色技能
  'staged-stages-only': [
    'stage:preprocessing',
    'stage:postprocessing',
  ],
  // ── 若切到 chain 引擎（九步）才适用 ──
  'chain-conservative': [
    'tactical_directive',
    'playbook_selection',
    'mask_selection',
    'action_rehearsal',
  ],
  'chain-mid': [
    'tactical_directive',
    'playbook_selection',
    'mask_selection',
    'action_rehearsal',
    'identity_inference',
  ],
};

/// 无论哪个预设都不能换的步骤（生成类）
const List<String> _neverReplace = [
  'core_cognition_or_speech', // staged 核心认知：写发言
  'speech_generation', // chain 发言生成
  'strategy_planning', // chain 策略规划
  'skill:discuss', // 白天讨论发言
  'skill:conspire', // 狼人战术会议
  'skill:testament', // 遗言
  'skill:sheriff_speech', // 竞选宣言
];

class _Record {
  _Record({
    required this.step,
    required this.model,
    required this.inTokens,
    required this.outTokens,
    required this.latencyMs,
    this.reportedCost,
  });

  final String step;
  final String model;
  final int inTokens;
  final int outTokens;
  final int latencyMs;

  /// 上游直接回报的费用（OpenRouter 的 usage.cost）。有则优先使用。
  final double? reportedCost;
}

class _Options {
  _Options({
    required this.logPath,
    required this.llmIn,
    required this.llmOut,
    required this.jevIn,
    required this.jevOut,
    required this.searchPattern,
    required this.modelIds,
    required this.configPath,
  });

  final String logPath;
  final double llmIn;
  final double llmOut;
  final double jevIn;
  final double jevOut;
  final String searchPattern;
  final List<String> modelIds;

  /// 配置文件路径：密钥从这里读（与游戏本体、jev_probe 共用一份）。
  final String configPath;
}

_Options _parseArgs(List<String> args) {
  var logPath = 'tool/llm_calls.jsonl';
  var llmIn = _defaultLlmIn;
  var llmOut = _defaultLlmOut;
  var jevIn = _defaultJevIn;
  var jevOut = _defaultJevOut;
  var searchPattern = 'jev|typesafe|systemone';
  final modelIds = <String>[
    'deepseek/deepseek-v4.1-flash',
    'typesafe/jev-1.13',
  ];
  var configPath = 'werewolf_config.yaml';

  for (var i = 0; i < args.length; i++) {
    String? next() => i + 1 < args.length ? args[++i] : null;
    switch (args[i]) {
      case '--log':
        logPath = next() ?? logPath;
      case '--in-price':
        llmIn = double.tryParse(next() ?? '') ?? llmIn;
      case '--out-price':
        llmOut = double.tryParse(next() ?? '') ?? llmOut;
      case '--jev-in-price':
        jevIn = double.tryParse(next() ?? '') ?? jevIn;
      case '--jev-out-price':
        jevOut = double.tryParse(next() ?? '') ?? jevOut;
      case '--search':
        searchPattern = next() ?? searchPattern;
      case '--config':
        configPath = next() ?? configPath;
      case '--id':
        final id = next();
        if (id != null && id.isNotEmpty) modelIds.add(id);
    }
  }
  return _Options(
    logPath: logPath,
    llmIn: llmIn,
    llmOut: llmOut,
    jevIn: jevIn,
    jevOut: jevOut,
    searchPattern: searchPattern,
    modelIds: modelIds,
    configPath: configPath,
  );
}

double _cost(int tokens, double pricePerMtok) => tokens / 1000000 * pricePerMtok;

/// 单次调用成本：优先用上游回报的 cost，缺失时按单价与 token 推算。
double _recordCost(_Record r, _Options o) =>
    r.reportedCost ?? (_cost(r.inTokens, o.llmIn) + _cost(r.outTokens, o.llmOut));

String _usd(double v) {
  if (v >= 1) return '\$${v.toStringAsFixed(4)}';
  if (v >= 0.0001) return '\$${v.toStringAsFixed(6)}';
  return '\$${v.toStringAsFixed(8)}';
}

String _fixed(double v, int digits) => v.toStringAsFixed(digits);

List<_Record> _loadRecords(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('找不到记录文件：$path');
    stderr.writeln('先跑：export OPENAI_API_KEY=... && dart tool/llm_proxy_recorder.dart');
    exit(2);
  }
  final records = <_Record>[];
  var badLines = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      records.add(
        _Record(
          step: json['step'] as String? ?? 'other',
          model: json['model'] as String? ?? 'unknown',
          inTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
          outTokens: (json['completion_tokens'] as num?)?.toInt() ?? 0,
          latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
          reportedCost: (json['cost'] as num?)?.toDouble(),
        ),
      );
    } catch (_) {
      badLines++;
    }
  }
  if (badLines > 0) {
    stdout.writeln('（跳过 $badLines 行无法解析的记录）');
  }
  return records;
}

/// 反事实：把 [replace] 里的步骤换成 Jev 之后的总成本。
///
/// 返回两个界：
/// - sum 界：每个步骤各自发一次 state（输入 = 各步输入之和）
/// - max 界：同一玩家回合共用一个 state，一次请求问多个问题
///   （输入近似为该回合各步输入的最大值，而非求和）
({double cost, double sumIn, double maxIn, int sumOut}) _counterfactual(
  List<_Record> records,
  Set<String> replace,
  _Options opts,
) {
  var sumIn = 0.0;
  var sumOut = 0;
  // 同一 (步内) 的记录按"回合组"近似：用每步输入均值估算共享 state 的下限开销
  final perStepIn = <String, List<int>>{};
  var keptCost = 0.0;

  for (final record in records) {
    if (replace.contains(record.step)) {
      sumIn += record.inTokens;
      sumOut += record.outTokens;
      perStepIn.putIfAbsent(record.step, () => []).add(record.inTokens);
    } else {
      // 与表头/合计保持同一计价基准：优先用上游回报的实际 cost。
      // 若这里退回单价公式，会与"实测总成本"混用两套基准，把降幅算高。
      keptCost += _recordCost(record, opts);
    }
  }

  // 合并界：同一玩家回合把该组问题放进一次请求，state 只发一次。
  // 每回合的调用数从 N 降到 1，所以输入 ≈ (总调用数 / 步骤数) × 单步输入。
  // 用最大的单步均值代入，避免过度乐观。
  var maxIn = 0.0;
  if (perStepIn.isNotEmpty) {
    final averages = perStepIn.values
        .map((list) => list.reduce((a, b) => a + b) / list.length)
        .toList()
      ..sort();
    final totalCalls = perStepIn.values.fold<int>(0, (a, b) => a + b.length);
    final turns = totalCalls / perStepIn.length;
    maxIn = turns * averages.last;
  }

  final sumCost = keptCost + _cost(sumIn.toInt(), opts.jevIn);
  return (cost: sumCost, sumIn: sumIn, maxIn: maxIn, sumOut: sumOut);
}

/// 极简 YAML 取值：只认"顶级段 + 二级标量键"（本项目配置文件的形状）。
/// 不是通用 YAML 解析器。
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

/// 密钥优先级：配置文件 > 环境变量（环境变量仅作兜底）。
String _resolveKey(_Options opts) {
  final fromConfig = _configValue(opts.configPath, 'default_llm', 'api_key');
  if (fromConfig != null) return fromConfig;
  return Platform.environment['OPENAI_API_KEY'] ??
      Platform.environment['OPENROUTER_API_KEY'] ??
      '';
}

Future<void> _checkModels(_Options opts) async {
  final key = _resolveKey(opts);
  if (key.isEmpty) {
    stdout.writeln('未读到 key（${opts.configPath} 未填或不存在），仅做匿名探测。');
  }
  final client = HttpClient();

  Future<({int status, String body})> get(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    if (key.isNotEmpty) {
      request.headers.set('Authorization', 'Bearer $key');
    }
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  }

  stdout.writeln('=== 端点元数据（权威：不受目录过滤影响）===');
  for (final id in opts.modelIds) {
    final result =
        await get('https://openrouter.ai/api/v1/models/$id/endpoints');
    if (result.status != 200) {
      stdout.writeln('  $id -> HTTP ${result.status}');
      continue;
    }
    final data = (jsonDecode(result.body) as Map)['data'] as Map;
    final architecture = data['architecture'] as Map?;
    stdout.writeln('  ${data['id']}   ${data['name']}');
    stdout.writeln(
      '    模态 ${architecture?['modality']}   '
      '输入 ${architecture?['input_modalities']}   '
      '输出 ${architecture?['output_modalities']}',
    );
    for (final raw in (data['endpoints'] as List? ?? const [])) {
      final endpoint = raw as Map;
      final pricing = endpoint['pricing'] as Map;
      final inPrice = double.tryParse(pricing['prompt'].toString()) ?? 0;
      final outPrice = double.tryParse(pricing['completion'].toString()) ?? 0;
      stdout.writeln(
        '    端点 ${endpoint['name']}   上下文 ${endpoint['context_length']}   '
        'in=${_usd(inPrice * 1000000)}/MTok   '
        'out=${_usd(outPrice * 1000000)}/MTok   '
        'uptime1d=${endpoint['uptime_last_1d']}%',
      );
    }
  }

  stdout.writeln('\n=== 目录清单（仅供说明）===');
  final catalog = await get('https://openrouter.ai/api/v1/models');
  if (catalog.status != 200) {
    stdout.writeln('  目录查询失败 HTTP ${catalog.status}');
    client.close();
    return;
  }
  final data = (jsonDecode(catalog.body) as Map)['data'] as List;
  final pattern = RegExp(opts.searchPattern, caseSensitive: false);
  final hits = data.where((raw) {
    final map = raw as Map;
    return pattern.hasMatch('${map['id']} ${map['name']}');
  }).toList();
  stdout.writeln(
    '  目录共 ${data.length} 个模型，按 /${opts.searchPattern}/ 命中 ${hits.length} 个',
  );
  if (hits.isEmpty) {
    stdout.writeln(
      '  说明：模态为 text->decisions 的模型不进目录（已知行为）。\n'
      '  目录零命中**不能**推断模型不可用——请以上面的端点元数据为准。',
    );
  } else {
    for (final raw in hits) {
      final map = raw as Map;
      final pricing = map['pricing'] as Map?;
      stdout.writeln(
        '  ${map['id']}  in=${pricing?['prompt']} out=${pricing?['completion']}',
      );
    }
  }
  client.close();
}

void _report(_Options opts) {
  final records = _loadRecords(opts.logPath);
  if (records.isEmpty) {
    stdout.writeln('记录文件是空的。');
    return;
  }

  // 按步骤聚合
  final byStep =
      <String, ({int calls, int inTok, int outTok, int latency, double cost})>{};
  for (final record in records) {
    final prev = byStep[record.step];
    byStep[record.step] = (
      calls: (prev?.calls ?? 0) + 1,
      inTok: (prev?.inTok ?? 0) + record.inTokens,
      outTok: (prev?.outTok ?? 0) + record.outTokens,
      latency: (prev?.latency ?? 0) + record.latencyMs,
      cost: (prev?.cost ?? 0) + _recordCost(record, opts),
    );
  }

  final totalIn = records.fold<int>(0, (a, r) => a + r.inTokens);
  final totalOut = records.fold<int>(0, (a, r) => a + r.outTokens);
  final totalCost = records.fold<double>(0, (a, r) => a + _recordCost(r, opts));

  stdout.writeln('记录文件：${opts.logPath}');
  stdout.writeln(
    '单价：LLM in=${_usd(opts.llmIn)}/MTok out=${_usd(opts.llmOut)}/MTok  |  '
    'Jev in=${_usd(opts.jevIn)}/MTok out=${_usd(opts.jevOut)}/MTok',
  );
  stdout.writeln('\n步骤                调用    输入token   输出token   成本        占比');
  stdout.writeln('-' * 74);
  final sorted = byStep.entries.toList()
    ..sort((a, b) => (b.value.inTok + b.value.outTok)
        .compareTo(a.value.inTok + a.value.outTok));
  for (final entry in sorted) {
    final stat = entry.value;
    final cost = stat.cost;
    final share = totalCost > 0 ? cost / totalCost * 100 : 0.0;
    stdout.writeln(
      '${entry.key.padRight(20)}'
      '${stat.calls.toString().padLeft(5)}'
      '${stat.inTok.toString().padLeft(12)}'
      '${stat.outTok.toString().padLeft(12)}'
      '  ${_usd(cost).padRight(13)}'
      '${_fixed(share, 1)}%',
    );
  }
  stdout.writeln('-' * 74);
  stdout.writeln(
    '${'合计'.padRight(20)}'
    '${records.length.toString().padLeft(5)}'
    '${totalIn.toString().padLeft(12)}'
    '${totalOut.toString().padLeft(12)}'
    '  ${_usd(totalCost)}',
  );

  stdout.writeln('\n=== 换成 Jev 后 ===');
  stdout.writeln('（不能换：${_neverReplace.join('、')}——生成类，Jev 不做文本生成）\n');
  for (final preset in _presets.entries) {
    final replace = preset.value.toSet();
    final result = _counterfactual(records, replace, opts);
    final sumRatio = result.cost > 0 ? totalCost / result.cost : 0.0;
    // max 界：扣掉求和后加回共享 state 的开销
    final maxCost = result.cost - _cost(result.sumIn.toInt(), opts.jevIn) +
        _cost(result.maxIn.toInt(), opts.jevIn);
    final maxRatio = maxCost > 0 ? totalCost / maxCost : 0.0;
    stdout.writeln('预设 ${preset.key.padRight(14)} 替换 ${replace.length} 个步骤');
    stdout.writeln(
      '  各步各自发 state：${_usd(result.cost)}  ->  降到 ${_fixed(sumRatio, 1)} 分之一',
    );
    stdout.writeln(
      '  合并成一次请求  ：${_usd(maxCost)}  ->  降到 ${_fixed(maxRatio, 1)} 分之一',
    );
    stdout.writeln(
      '  （省下的原始输出 token：${result.sumOut}，Jev 输出不计费）',
    );
  }
  stdout.writeln(
    '\n注：两界含义——\n'
    '  各步各自发 state：保守。每步仍按原样单独调用 Jev，输入不共享。\n'
    '  合并成一次请求：乐观。前提是这一组问题相互独立、能共用同一份 state 一次问完\n'
    '  （官方 speculative fan-out 的用法）。若步骤之间有依赖（后一步要读前一步的输出），\n'
    '  则不能合并，应参考保守界。',
  );
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'check') {
    await _checkModels(_parseArgs(args.sublist(1)));
    return;
  }
  _report(_parseArgs(args));
}
