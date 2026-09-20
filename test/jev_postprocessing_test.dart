// Jev 安全检查的 state 构造与结论映射测试（纯函数，不需要网络）。

import 'package:flutter_test/flutter_test.dart';
import 'package:werewolf_arena/engine/reasoning/jev/jev_postprocessing_checker.dart';
import 'package:werewolf_arena/engine/reasoning/jev/system_one_client.dart';

void main() {
  group('JevPostprocessing.buildState', () {
    test('state 里必须给出真实身份，判定才可能识别泄露', () {
      final state = JevPostprocessing.buildState(
        playerName: '3号玩家',
        role: '狼人',
        faction: '狼人',
        teammates: ['1号玩家', '7号玩家'],
        speech: '我觉得 5 号很可疑。',
        strategy: '跟票，不要出头。',
      );
      expect(state, contains('3号玩家'));
      expect(state, contains('狼人'));
      expect(state, contains('1号玩家, 7号玩家'));
      expect(state, contains('我觉得 5 号很可疑。'));
      expect(state, contains('跟票，不要出头。'));
    });

    test('好人没有队友时不出现队友行', () {
      final state = JevPostprocessing.buildState(
        playerName: '5号玩家',
        role: '村民',
        faction: '好人',
        teammates: const [],
        speech: '我听听再说。',
        strategy: '',
      );
      expect(state, isNot(contains('队友')));
      expect(state, isNot(contains('本轮的策略')));
    });
  });

  group('JevPostprocessing.toVerdict', () {
    test('各项都低于阈值即放行', () {
      final verdict = JevPostprocessing.toVerdict({
        'leak_secret': const SystemOneAnswer(type: 'noul', noul: 0.12),
        'violate_role': const SystemOneAnswer(type: 'noul', noul: 0.08),
        'inappropriate': const SystemOneAnswer(type: 'noul', noul: 0.03),
      });
      expect(verdict.passed, isTrue);
      expect(verdict.report, '未发现明显问题');
    });

    test('命中时报告按概率降序列出类别', () {
      final verdict = JevPostprocessing.toVerdict({
        'leak_secret': const SystemOneAnswer(type: 'noul', noul: 0.91),
        'violate_role': const SystemOneAnswer(type: 'noul', noul: 0.62),
        'inappropriate': const SystemOneAnswer(type: 'noul', noul: 0.10),
      });
      expect(verdict.passed, isFalse);
      expect(verdict.report, contains('泄露秘密信息(0.91)'));
      expect(verdict.report, contains('违反角色设定(0.62)'));
      expect(verdict.report, isNot(contains('不当言论')));
      expect(
        verdict.report.indexOf('泄露秘密信息'),
        lessThan(verdict.report.indexOf('违反角色设定')),
      );
    });

    test('恰好等于阈值算命中（不放过边界）', () {
      final verdict = JevPostprocessing.toVerdict(
        {'leak_secret': const SystemOneAnswer(type: 'noul', noul: 0.5)},
        threshold: 0.5,
      );
      expect(verdict.passed, isFalse);
    });

    test('阈值可调，宽松配置下同一结果可能放行', () {
      final answers = {
        'leak_secret': const SystemOneAnswer(type: 'noul', noul: 0.6),
      };
      expect(JevPostprocessing.toVerdict(answers, threshold: 0.5).passed, isFalse);
      expect(JevPostprocessing.toVerdict(answers, threshold: 0.8).passed, isTrue);
    });

    test('缺少某项答案时不会误判为命中', () {
      final verdict = JevPostprocessing.toVerdict({
        'inappropriate': const SystemOneAnswer(type: 'noul', noul: 0.02),
      });
      expect(verdict.passed, isTrue);
      expect(verdict.probabilities.keys, ['inappropriate']);
    });

    test('答案类型不符（如误返回 choice）时不崩且不误判', () {
      final verdict = JevPostprocessing.toVerdict({
        'leak_secret': const SystemOneAnswer(
          type: 'choice',
          choice: '不通过',
          probabilities: {'不通过': 0.9},
        ),
      });
      expect(verdict.passed, isTrue);
    });
  });
}
