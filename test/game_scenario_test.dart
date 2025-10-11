import 'package:test/test.dart';
import 'package:werewolf_arena/core/scenarios/scenario_9_players.dart';
import 'package:werewolf_arena/core/scenarios/scenario_12_players.dart';
import 'package:werewolf_arena/core/domain/enums/role_type.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/domain/entities/role_implementations.dart';

void main() {
  group('Scenario9Players Tests', () {
    late Scenario9Players scenario;

    setUp(() {
      scenario = Scenario9Players();
    });

    test('基本属性测试', () {
      expect(scenario.id, equals('standard_9_players'));
      expect(scenario.name, equals('标准9人局'));
      expect(scenario.description, equals('经典狼人杀9人局配置'));
      expect(scenario.playerCount, equals(9));
    });

    test('游戏规则描述测试', () {
      expect(scenario.rule, isNotEmpty);
      expect(scenario.rule, contains('狼人'));
      expect(scenario.rule, contains('预言家'));
      expect(scenario.rule, contains('女巫'));
      expect(scenario.rule, contains('守卫'));
      expect(scenario.rule, contains('猎人'));
      expect(scenario.rule, contains('村民'));
    });

    test('角色分配测试', () {
      final distribution = scenario.roleDistribution;

      expect(distribution[RoleType.werewolf], equals(2));
      expect(distribution[RoleType.villager], equals(3));
      expect(distribution[RoleType.seer], equals(1));
      expect(distribution[RoleType.witch], equals(1));
      expect(distribution[RoleType.guard], equals(1));
      expect(distribution[RoleType.hunter], equals(1));

      // 验证总数为9
      final total = distribution.values.fold(0, (sum, count) => sum + count);
      expect(total, equals(9));
    });

    test('扩展角色列表测试', () {
      final expandedRoles = scenario.getExpandedGameRoles();

      expect(expandedRoles.length, equals(9));

      // 统计每种角色的数量
      final counts = <RoleType, int>{};
      for (final role in expandedRoles) {
        counts[role] = (counts[role] ?? 0) + 1;
      }

      expect(counts[RoleType.werewolf], equals(2));
      expect(counts[RoleType.villager], equals(3));
      expect(counts[RoleType.seer], equals(1));
      expect(counts[RoleType.witch], equals(1));
      expect(counts[RoleType.guard], equals(1));
      expect(counts[RoleType.hunter], equals(1));
    });

    test('角色创建测试', () {
      // 测试每种角色的创建
      final werewolf = scenario.createGameRole(RoleType.werewolf);
      expect(werewolf, isA<WerewolfRole>());
      expect(werewolf.isWerewolf, isTrue);

      final villager = scenario.createGameRole(RoleType.villager);
      expect(villager, isA<VillagerRole>());
      expect(villager.isWerewolf, isFalse);

      final seer = scenario.createGameRole(RoleType.seer);
      expect(seer, isA<SeerRole>());
      expect(seer.isWerewolf, isFalse);

      final witch = scenario.createGameRole(RoleType.witch);
      expect(witch, isA<WitchRole>());
      expect(witch.isWerewolf, isFalse);

      final guard = scenario.createGameRole(RoleType.guard);
      expect(guard, isA<GuardRole>());
      expect(guard.isWerewolf, isFalse);

      final hunter = scenario.createGameRole(RoleType.hunter);
      expect(hunter, isA<HunterRole>());
      expect(hunter.isWerewolf, isFalse);
    });

    test('胜利条件检查测试', () {
      // 创建测试用的玩家列表
      final players = <GamePlayer>[];

      // 创建2个狼人
      for (int i = 0; i < 2; i++) {
        final werewolf = GamePlayer.ai(
          id: 'werewolf_$i',
          name: '狼人${i + 1}',
          role: scenario.createGameRole(RoleType.werewolf),
          driver: null, // 测试中不需要实际的driver
        );
        players.add(werewolf);
      }

      // 创建7个好人
      final goodRoles = [
        RoleType.villager,
        RoleType.villager,
        RoleType.villager,
        RoleType.seer,
        RoleType.witch,
        RoleType.guard,
        RoleType.hunter,
      ];
      for (int i = 0; i < goodRoles.length; i++) {
        final goodGuy = GamePlayer.ai(
          id: 'good_$i',
          name: '好人${i + 1}',
          role: scenario.createGameRole(goodRoles[i]),
          driver: null,
        );
        players.add(goodGuy);
      }

      // 创建游戏状态
      var gameState = GameState(
        gameId: 'test_game',
        scenario: scenario,
        players: players,
        dayNumber: 1,
      );

      // 测试初始状态 - 游戏继续
      var result = scenario.checkVictoryCondition(gameState);
      expect(result.isGameContinues, isTrue);

      // 测试狼人胜利 - 狼人数量≥好人数量
      // 让6个好人死亡，剩下2狼1好人
      for (int i = 2; i < 8; i++) {
        players[i].isDead = true;
      }
      gameState = GameState(
        gameId: 'test_game_2',
        scenario: scenario,
        players: players,
        dayNumber: 2,
      );

      result = scenario.checkVictoryCondition(gameState);
      expect(result.isEvilWins, isTrue);
      expect(result.reason, contains('狼人数量≥好人数量'));

      // 重置玩家状态
      for (final player in players) {
        player.isDead = false;
      }

      // 测试好人胜利 - 所有狼人死亡
      players[0].isDead = true; // 狼人1死亡
      players[1].isDead = true; // 狼人2死亡
      gameState = GameState(
        gameId: 'test_game_3',
        scenario: scenario,
        players: players,
        dayNumber: 3,
      );

      result = scenario.checkVictoryCondition(gameState);
      expect(result.isGoodWins, isTrue);
      expect(result.reason, contains('所有狼人已被消灭'));
    });
  });

  group('Scenario12Players Tests', () {
    late Scenario12Players scenario;

    setUp(() {
      scenario = Scenario12Players();
    });

    test('基本属性测试', () {
      expect(scenario.id, equals('standard_12_players'));
      expect(scenario.name, equals('标准12人局'));
      expect(scenario.description, contains('4狼4民4神'));
      expect(scenario.playerCount, equals(12));
    });

    test('角色分配测试', () {
      final distribution = scenario.roleDistribution;

      // 验证总数为12
      final total = distribution.values.fold(0, (sum, count) => sum + count);
      expect(total, equals(12));

      // 验证包含狼人（应该有3-4个）
      expect(distribution[RoleType.werewolf], greaterThanOrEqualTo(3));
      expect(distribution[RoleType.werewolf], lessThanOrEqualTo(4));
    });

    test('扩展角色列表测试', () {
      final expandedRoles = scenario.getExpandedGameRoles();
      expect(expandedRoles.length, equals(12));

      // 统计每种角色的数量应该与distribution一致
      final counts = <RoleType, int>{};
      for (final role in expandedRoles) {
        counts[role] = (counts[role] ?? 0) + 1;
      }

      scenario.roleDistribution.forEach((role, expectedCount) {
        expect(
          counts[role],
          equals(expectedCount),
          reason: '角色 $role 的数量应该是 $expectedCount',
        );
      });
    });
  });

  group('GameScenario 通用接口测试', () {
    test('9人局和12人局都应该实现完整的GameScenario接口', () {
      final scenarios = [Scenario9Players(), Scenario12Players()];

      for (final scenario in scenarios) {
        // 基本属性不为空
        expect(scenario.id, isNotEmpty);
        expect(scenario.name, isNotEmpty);
        expect(scenario.description, isNotEmpty);
        expect(scenario.rule, isNotEmpty);
        expect(scenario.playerCount, greaterThan(0));

        // 角色分配不为空且总数正确
        expect(scenario.roleDistribution, isNotEmpty);
        final total = scenario.roleDistribution.values.fold(
          0,
          (sum, count) => sum + count,
        );
        expect(total, equals(scenario.playerCount));

        // 扩展角色列表长度正确
        expect(
          scenario.getExpandedGameRoles().length,
          equals(scenario.playerCount),
        );

        // 能够创建所有类型的角色
        for (final roleType in scenario.roleDistribution.keys) {
          final role = scenario.createGameRole(roleType);
          expect(role, isNotNull);
        }
      }
    });

    test('角色分配应该平衡', () {
      final scenario9 = Scenario9Players();
      final scenario12 = Scenario12Players();

      // 9人局：2狼 vs 7好人，狼人比例约22%
      final werewolves9 = scenario9.roleDistribution[RoleType.werewolf]!;
      final total9 = scenario9.playerCount;
      final werewolfRatio9 = werewolves9 / total9;
      expect(werewolfRatio9, greaterThan(0.15)); // 至少15%
      expect(werewolfRatio9, lessThan(0.35)); // 不超过35%

      // 12人局：狼人比例应该类似
      final werewolves12 = scenario12.roleDistribution[RoleType.werewolf]!;
      final total12 = scenario12.playerCount;
      final werewolfRatio12 = werewolves12 / total12;
      expect(werewolfRatio12, greaterThan(0.15));
      expect(werewolfRatio12, lessThan(0.35));
    });
  });
}
