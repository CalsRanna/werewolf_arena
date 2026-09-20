// 预处理三类拆分的单元测试。
//
// 重点验证两条行为约束：
//   1) 事件历史必须用 toNarrative() 渲染 —— 用 toString() 会退化成
//      `GameEvent(<id>)`，等于把整条历史通道变成一串不透明 ID。
//   2) 无信息阶段不应产出任何"推测"——事实由代码拼，判定留空。

import 'package:flutter_test/flutter_test.dart';
import 'package:werewolf_arena/engine/event/game_start_event.dart';
import 'package:werewolf_arena/engine/event/order_event.dart';
import 'package:werewolf_arena/engine/event/peaceful_night_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/staged/preprocessing_facts.dart';
import 'package:werewolf_arena/engine/role/villager_role.dart';
import 'package:werewolf_arena/engine/role/werewolf_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// GamePlayer 是抽象类（唯一抽象成员是 cast），测试只需要一个最轻的实现。
class _FakePlayer extends GamePlayer {
  _FakePlayer({
    required super.id,
    required super.index,
    required super.role,
    required super.name,
  });

  @override
  Future<SkillResult> cast(GameSkill skill, dynamic context) =>
      throw UnimplementedError('测试不执行技能');
}

GamePlayer _player(String number, {required bool wolf}) => _FakePlayer(
  id: 'p$number',
  index: int.parse(number) - 1,
  role: wolf ? WerewolfRole() : VillagerRole(),
  name: '$number号玩家',
);

void main() {
  group('hasInformativeHistory', () {
    test('空历史不是信息', () {
      expect(PreprocessingFacts.hasInformativeHistory([]), isFalse);
    });

    test('纯登记事件（开局）不算信息', () {
      expect(
        PreprocessingFacts.hasInformativeHistory([GameStartEvent()]),
        isFalse,
      );
    });

    test('发言顺序通知不算信息（它每回合开局都有，否则短路永远不触发）', () {
      expect(
        PreprocessingFacts.hasInformativeHistory([
          OrderEvent(day: 1, players: [_player('1', wolf: false)]),
        ]),
        isFalse,
      );
    });

    test('真正发生过的对局事件才算信息', () {
      expect(
        PreprocessingFacts.hasInformativeHistory([PeacefulNightEvent()]),
        isTrue,
      );
    });

    test('登记事件与真实事件混在一起时仍算有信息', () {
      final voter = _player('1', wolf: false);
      final candidate = _player('2', wolf: true);
      expect(
        PreprocessingFacts.hasInformativeHistory([
          GameStartEvent(),
          VoteEvent(voter: voter, candidate: candidate, day: 1),
        ]),
        isTrue,
      );
    });
  });

  group('renderHistory', () {
    test('渲染必须给出可读文本，而不是 GameEvent(<id>)', () {
      final text = PreprocessingFacts.renderHistory([PeacefulNightEvent()]);
      expect(text, contains('平安夜'));
      expect(
        text,
        isNot(contains('GameEvent(')),
        reason: '用了 toString() 就会渲染成不透明 ID，这正是本次修复的缺陷',
      );
    });

    test('保留天数前缀，便于模型按时间线理解', () {
      final text = PreprocessingFacts.renderHistory([PeacefulNightEvent()]);
      expect(text, contains('[第0天]'));
    });
  });

  group('stripTaskSection', () {
    test('去掉给生成模型的 JSON 格式说明', () {
      const prompt = '# 游戏信息\n存活: 1号玩家\n\n# 任务：整理为结构化JSON\n```json\n{}\n```';
      final stripped = PreprocessingFacts.stripTaskSection(prompt);
      expect(stripped, contains('游戏信息'));
      expect(stripped, isNot(contains('任务')));
      expect(stripped, isNot(contains('```')));
    });

    test('没有任务段时原样返回', () {
      expect(PreprocessingFacts.stripTaskSection('纯事实'), '纯事实');
    });
  });

  group('build（事实层由代码拼）', () {
    late GamePlayer wolf1;
    late GamePlayer wolf2;
    late GamePlayer villager;
    late List<GamePlayer> all;

    setUp(() {
      wolf1 = _player('1', wolf: true);
      wolf2 = _player('2', wolf: true);
      villager = _player('3', wolf: false);
      all = [wolf1, wolf2, villager];
    });

    test('身份与阵营直接来自代码，不经过模型', () {
      final state = PreprocessingFacts.build(
        player: wolf1,
        allPlayers: all,
        alivePlayers: all,
      );
      expect(state.selfInfo.name, '1号玩家');
      expect(state.selfInfo.number, '1');
      expect(state.selfInfo.role, '狼人');
      expect(state.selfInfo.faction, '狼人');
      // 队友只含其他狼，不含自己
      expect(state.selfInfo.teammates, ['2号玩家']);
    });

    test('好人没有队友字段', () {
      final state = PreprocessingFacts.build(
        player: villager,
        allPlayers: all,
        alivePlayers: all,
      );
      expect(state.selfInfo.teammates, isEmpty);
      expect(state.selfInfo.faction, '好人');
    });

    test('存活状态按 alivePlayers 判定，排除自己', () {
      final state = PreprocessingFacts.build(
        player: wolf1,
        allPlayers: all,
        alivePlayers: [wolf1, villager],
      );
      expect(state.otherPlayers.map((p) => p.name), ['2号玩家', '3号玩家']);
      expect(
        state.otherPlayers.firstWhere((p) => p.name == '2号玩家').isAlive,
        isFalse,
      );
      expect(
        state.otherPlayers.firstWhere((p) => p.name == '3号玩家').isAlive,
        isTrue,
      );
    });

    test('无判定输入时不产出任何推测，也不编造文本', () {
      final state = PreprocessingFacts.build(
        player: wolf1,
        allPlayers: all,
        alivePlayers: all,
      );
      expect(state.otherPlayers.every((p) => p.estimatedRole == null), isTrue);
      expect(
        state.otherPlayers.every((p) => p.estimatedConfidence == null),
        isTrue,
      );
      expect(state.keyEvents, isEmpty);
      expect(state.situationSummary, isEmpty);
      expect(state.coreConflict, isNull);
    });

    test('判定层的输出被原样装配进 WorldState', () {
      final state = PreprocessingFacts.build(
        player: wolf1,
        allPlayers: all,
        alivePlayers: all,
        judgments: const PreprocessingJudgments(
          roleByPlayer: {'3号玩家': '狼人'},
          confidenceByPlayer: {'3号玩家': 72},
          hostilities: {
            '1号玩家': ['3号玩家'],
          },
          mostSuspicious: ['3号玩家'],
        ),
      );
      final third = state.otherPlayers.firstWhere((p) => p.name == '3号玩家');
      expect(third.estimatedRole, '狼人');
      expect(third.estimatedConfidence, 72);
      expect(state.socialRelationships.hostilities['1号玩家'], ['3号玩家']);
      expect(state.socialRelationships.myMostSuspicious, ['3号玩家']);
    });
  });
}
