import 'package:werewolf_arena/engine/reasoning/jev/system_one_client.dart';

/// 安全检查的判定结论。
class PostprocessingVerdict {
  const PostprocessingVerdict({
    required this.passed,
    required this.probabilities,
    required this.report,
  });

  /// 是否放行（各项风险都低于阈值）
  final bool passed;

  /// 各风险类别的概率，键为类别 id
  final Map<String, double> probabilities;

  /// 报告文本。由代码按命中的类别拼装——
  /// 判定模型不生成文本，所以理由以"类别 + 概率"的形式给出。
  final String report;
}

/// 安全检查器接口。真实实现走 Jev；测试用假实现。
abstract class PostprocessingChecker {
  Future<PostprocessingVerdict> check({
    required String playerName,
    required String role,
    required String faction,
    required List<String> teammates,
    required String speech,
    required String strategy,
  });
}

/// 用 Jev 做发言安全检查。
///
/// 原实现让生成模型输出 {passed, report, final_speech, needs_regeneration}，
/// 其中只有 final_speech 与 report 被调用方使用（needs_regeneration 未被读取）。
/// 这里把"判定"与"改写"拆开：
///   判定通过 → 直接放行，不调用生成模型（绝大多数情况）
///   判定命中 → 回落到原有生成式路径，由它产出 final_speech
class JevPostprocessingChecker implements PostprocessingChecker {
  JevPostprocessingChecker({required this.client, this.threshold = 0.5});

  final SystemOneClient client;

  /// 命中阈值。原实现强调"宽松为主"，因此取中性值。
  final double threshold;

  @override
  Future<PostprocessingVerdict> check({
    required String playerName,
    required String role,
    required String faction,
    required List<String> teammates,
    required String speech,
    required String strategy,
  }) async {
    final result = await client.evaluate(
      state: JevPostprocessing.buildState(
        playerName: playerName,
        role: role,
        faction: faction,
        teammates: teammates,
        speech: speech,
        strategy: strategy,
      ),
      questions: JevPostprocessing.questions,
    );
    return JevPostprocessing.toVerdict(
      result.answers,
      threshold: threshold,
    );
  }
}

/// 安全检查的 state 与问题集（纯函数，便于单测）。
class JevPostprocessing {
  JevPostprocessing._();

  static const String _leakSecret = 'leak_secret';
  static const String _violateRole = 'violate_role';
  static const String _inappropriate = 'inappropriate';

  /// 类别 id -> 人类可读名（用于拼报告）
  static const Map<String, String> categoryNames = {
    _leakSecret: '泄露秘密信息',
    _violateRole: '违反角色设定',
    _inappropriate: '不当言论',
  };

  /// 判定模型默认不把 state 当敌意内容，而这里的 state 恰好是被检查的发言；
  /// 因此问题措辞必须写死判据，不能留"凭常识理解"的余地。
  static const Map<String, Object?> questions = {
    _leakSecret: {
      'type': 'noul',
      'instructions':
          '待检查的发言里，是否**直接说出**了该玩家自己的秘密信息？'
          '秘密信息指：自己的狼人身份、狼队友的姓名、'
          '尚未公开的查验结果 / 守护记录 / 用药记录。'
          '只依据发言文本本身判断；巧妙的暗示不算，直接点名才算。',
    },
    _violateRole: {
      'type': 'noul',
      'instructions':
          '待检查的发言是否与该玩家声称的角色设定冲突？'
          '注意：狼人悍跳预言家、平民伪装等**属于正常策略，不算冲突**；'
          '只有自相矛盾（如一会儿说自己是村民、一会儿说自己是女巫）才算。',
    },
    _inappropriate: {
      'type': 'noul',
      'instructions':
          '待检查的发言是否包含针对其他玩家的人身攻击或歧视性言论？'
          '基于游戏逻辑的质疑、指认、施压都**不算**。',
    },
  };

  static String buildState({
    required String playerName,
    required String role,
    required String faction,
    required List<String> teammates,
    required String speech,
    required String strategy,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# 该玩家的真实身份');
    buffer.writeln('- 名称: $playerName');
    buffer.writeln('- 角色: $role');
    buffer.writeln('- 阵营: $faction');
    if (teammates.isNotEmpty) {
      buffer.writeln('- 队友: ${teammates.join(", ")}');
    }
    if (strategy.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('# 该玩家本轮的策略');
      buffer.writeln(strategy);
    }
    buffer.writeln();
    buffer.writeln('# 待检查的公开发言');
    buffer.writeln(speech);
    return buffer.toString();
  }

  static PostprocessingVerdict toVerdict(
    Map<String, SystemOneAnswer> answers, {
    double threshold = 0.5,
  }) {
    final probabilities = <String, double>{};
    for (final id in categoryNames.keys) {
      final answer = answers[id];
      if (answer?.noul != null) probabilities[id] = answer!.noul!;
    }

    final hit = probabilities.entries
        .where((entry) => entry.value >= threshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (hit.isEmpty) {
      return PostprocessingVerdict(
        passed: true,
        probabilities: probabilities,
        report: '未发现明显问题',
      );
    }

    return PostprocessingVerdict(
      passed: false,
      probabilities: probabilities,
      report:
          '命中：${hit.map((e) => '${categoryNames[e.key]}'
              '(${e.value.toStringAsFixed(2)})').join('、')}',
    );
  }
}
