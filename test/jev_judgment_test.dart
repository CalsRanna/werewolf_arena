// Jev 判定层的问题构造与答案映射测试。
//
// 这一层是纯函数：给定玩家名单产出问题集，给定 answers 产出判定结果。
// 网络调用不在这里测（由 SystemOneClient 负责），因此无需任何 mock 服务器。

import 'package:flutter_test/flutter_test.dart';
import 'package:werewolf_arena/engine/reasoning/jev/jev_judgment_provider.dart';
import 'package:werewolf_arena/engine/reasoning/jev/system_one_client.dart';

void main() {
  group('JevQuestions.build', () {
    test('每个玩家各产出一个 noul 与一个 choice', () {
      final questions = JevQuestions.build(
        players: ['1号玩家', '2号玩家', '12号玩家'],
      );
      expect(questions.keys.toSet(), {
        'p1_wolf',
        'p1_role',
        'p2_wolf',
        'p2_role',
        'p12_wolf',
        'p12_role',
      });
      expect((questions['p1_wolf'] as Map)['type'], 'noul');
      expect((questions['p1_role'] as Map)['type'], 'choice');
    });

    test('角色选项里必须显式包含"未知"，否则信息不足时会被迫硬选', () {
      final questions = JevQuestions.build(players: ['1号玩家']);
      final criteria =
          (questions['p1_role'] as Map)['criteria'] as Map<String, String>;
      expect(criteria.keys, contains('未知'));
      expect(criteria.keys.length, greaterThanOrEqualTo(6));
    });

    test('问题文本里用号码而不是"号玩家"，避免冗长表述', () {
      final questions = JevQuestions.build(players: ['7号玩家']);
      final instructions = (questions['p7_wolf'] as Map)['instructions'] as String;
      expect(instructions, contains('7 号玩家'));
      expect(instructions, isNot(contains('7号玩家号')));
    });
  });

  group('JevJudgments.fromAnswers', () {
    test('概率直接当置信度用（不是模型自报的把握）', () {
      final judgments = JevJudgments.fromAnswers({
        'p3_wolf': const SystemOneAnswer(type: 'noul', noul: 0.72),
      });
      expect(judgments.confidenceByPlayer['3号玩家'], 72);
    });

    test('角色选择映射回"号玩家"命名的键', () {
      final judgments = JevJudgments.fromAnswers({
        'p5_role': const SystemOneAnswer(
          type: 'choice',
          choice: '预言家',
          probabilities: {'预言家': 0.6, '未知': 0.2},
        ),
      });
      expect(judgments.roleByPlayer['5号玩家'], '预言家');
    });

    test('最怀疑名单按概率降序，且只收达到阈值的', () {
      final judgments = JevJudgments.fromAnswers({
        'p1_wolf': const SystemOneAnswer(type: 'noul', noul: 0.9),
        'p2_wolf': const SystemOneAnswer(type: 'noul', noul: 0.5),
        'p3_wolf': const SystemOneAnswer(type: 'noul', noul: 0.3),
        'p4_wolf': const SystemOneAnswer(type: 'noul', noul: 0.05),
      });
      expect(judgments.mostSuspicious, ['1号玩家', '2号玩家', '3号玩家']);
    });

    test('全部低于阈值时最怀疑名单为空', () {
      final judgments = JevJudgments.fromAnswers({
        'p1_wolf': const SystemOneAnswer(type: 'noul', noul: 0.2),
        'p2_wolf': const SystemOneAnswer(type: 'noul', noul: 0.1),
      });
      expect(judgments.mostSuspicious, isEmpty);
    });

    test('最怀疑名单最多三人', () {
      final judgments = JevJudgments.fromAnswers({
        for (var i = 1; i <= 6; i++)
          'p${i}_wolf': const SystemOneAnswer(type: 'noul', noul: 0.8),
      });
      expect(judgments.mostSuspicious.length, 3);
    });

    test('无关键与异常答案不导致崩溃', () {
      final judgments = JevJudgments.fromAnswers({
        'not_a_question': const SystemOneAnswer(type: 'noul', noul: 0.9),
        'p1_role': const SystemOneAnswer(type: 'choice'),
      });
      expect(judgments.roleByPlayer, isEmpty);
      expect(judgments.confidenceByPlayer, isEmpty);
    });
  });
}
