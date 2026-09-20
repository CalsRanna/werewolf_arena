import 'package:werewolf_arena/engine/reasoning/jev/system_one_client.dart';
import 'package:werewolf_arena/engine/reasoning/staged/preprocessing_facts.dart';

/// 用 Jev 做预处理里的"判定"那一层。
///
/// 只回答答案空间可枚举的问题：每个玩家是不是狼、像哪个角色。
/// 事实由 [PreprocessingFacts] 用代码拼，自由文本仍归生成模型。
class JevJudgmentProvider implements JudgmentProvider {
  JevJudgmentProvider({required this.client});

  final SystemOneClient client;

  @override
  Future<PreprocessingJudgments> judge({
    required String state,
    required List<String> players,
  }) async {
    final result = await client.evaluate(
      state: state,
      questions: JevQuestions.build(players: players),
    );
    return JevJudgments.fromAnswers(result.answers);
  }
}

/// 问题集构造（纯函数，便于单测）。
class JevQuestions {
  JevQuestions._();

  /// 可枚举的角色答案空间。Jev 的 choice 是相对选择，
  /// "未知"必须显式列出来，否则信息不足时它会硬选一个。
  static const Map<String, String> roleCriteria = {
    '狼人': '发言在伪装或带节奏，或与他人形成可疑的配合',
    '预言家': '明确声称自己是预言家并给出验人信息',
    '女巫': '明确声称自己是女巫，或提到用药与救人',
    '猎人': '明确声称自己是猎人，或提到开枪',
    '守卫': '明确声称自己是守卫，或提到守护目标',
    '村民': '没有特殊信息，按逻辑讨论的普通好人',
    '未知': '以上都不成立，或信息不足以下判断',
  };

  static String _number(String playerName) =>
      playerName.replaceAll('号玩家', '');

  static Map<String, Object?> build({required List<String> players}) => {
    for (final name in players)
      'p${_number(name)}_wolf': {
        'type': 'noul',
        'instructions':
            '${_number(name)} 号玩家是狼人的概率有多高？'
            '只依据 state 里实际出现的发言与事件判断，不要臆测。'
            '若几乎没有可用信息，给出接近基础概率的低值。',
      },
    for (final name in players)
      'p${_number(name)}_role': {
        'type': 'choice',
        'instructions': '${_number(name)} 号玩家最可能是什么角色？',
        'criteria': roleCriteria,
      },
  };
}

/// 答案到判定结果的映射（纯函数，便于单测）。
class JevJudgments {
  JevJudgments._();

  /// 多少概率以上算"值得怀疑"，用于填 mostSuspicious。
  static const double suspicionFloor = 0.25;

  static PreprocessingJudgments fromAnswers(
    Map<String, SystemOneAnswer> answers,
  ) {
    final roleByNumber = <String, String>{};
    final confidenceByNumber = <String, int>{};
    final wolfProbabilityByNumber = <String, double>{};

    for (final entry in answers.entries) {
      final match = RegExp(r'^p(\d+)_(wolf|role)$').firstMatch(entry.key);
      if (match == null) continue;
      final number = match.group(1)!;
      final answer = entry.value;
      if (match.group(2) == 'wolf') {
        final probability = answer.noul;
        if (probability != null) {
          wolfProbabilityByNumber[number] = probability;
          // 置信度直接取概率本身：这是校准过的量，
          // 不是模型自报的"我觉得我有 90% 把握"。
          confidenceByNumber[number] = (probability * 100).round();
        }
      } else if (answer.choice != null) {
        roleByNumber[number] = answer.choice!;
      }
    }

    // 名字统一补回"号玩家"后缀，与 WorldState 的键保持一致
    String fullName(String number) => '$number号玩家';

    final ranked = wolfProbabilityByNumber.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PreprocessingJudgments(
      roleByPlayer: {
        for (final entry in roleByNumber.entries)
          fullName(entry.key): entry.value,
      },
      confidenceByPlayer: {
        for (final entry in confidenceByNumber.entries)
          fullName(entry.key): entry.value,
      },
      mostSuspicious: [
        for (final entry in ranked.where((e) => e.value >= suspicionFloor).take(3))
          fullName(entry.key),
      ],
    );
  }
}
