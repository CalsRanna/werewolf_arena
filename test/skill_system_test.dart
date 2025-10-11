import 'package:test/test.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/skills/skill_processor.dart';
import 'package:werewolf_arena/engine/skills/night_skills.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/ai_player.dart';
import 'package:werewolf_arena/engine/domain/entities/role_implementations.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_9_players.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';

void main() {
  group('SkillResult Tests', () {
    late GamePlayer mockPlayer;
    late GamePlayer mockTarget;

    setUp(() {
      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      mockPlayer = AIPlayer(
        id: 'player1',
        name: '玩家1',
        index: 1,
        role: WerewolfRole(),
        intelligence: intelligence,
      );

      mockTarget = AIPlayer(
        id: 'player2',
        name: '玩家2',
        index: 2,
        role: VillagerRole(),
        intelligence: intelligence,
      );
    });

    test('SkillResult.success创建成功结果', () {
      final result = SkillResult.success(
        caster: mockPlayer,
        target: mockTarget,
        metadata: {'test': 'data'},
      );

      expect(result.success, isTrue);
      expect(result.caster, equals(mockPlayer));
      expect(result.target, equals(mockTarget));
      expect(result.metadata['test'], equals('data'));
    });

    test('SkillResult.failure创建失败结果', () {
      final result = SkillResult.failure(
        caster: mockPlayer,
        metadata: {'error': 'test error'},
      );

      expect(result.success, isFalse);
      expect(result.caster, equals(mockPlayer));
      expect(result.target, isNull);
      expect(result.metadata['error'], equals('test error'));
    });

    test('SkillResult.noTarget创建无目标结果', () {
      final result = SkillResult.noTarget(
        caster: mockPlayer,
        success: true,
        metadata: {'action': 'skip'},
      );

      expect(result.success, isTrue);
      expect(result.caster, equals(mockPlayer));
      expect(result.target, isNull);
      expect(result.metadata['action'], equals('skip'));
    });

    test('SkillResult相等性测试', () {
      final result1 = SkillResult.success(
        caster: mockPlayer,
        target: mockTarget,
      );

      final result2 = SkillResult.success(
        caster: mockPlayer,
        target: mockTarget,
      );

      final result3 = SkillResult.failure(
        caster: mockPlayer,
        target: mockTarget,
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('SkillResult toString测试', () {
      final result = SkillResult.success(
        caster: mockPlayer,
        target: mockTarget,
        metadata: {'test': 'data'},
      );

      final str = result.toString();
      expect(str, contains('success: true'));
      expect(str, contains('caster: $mockPlayer'));
      expect(str, contains('target: $mockTarget'));
    });
  });

  group('GameSkill基础功能测试', () {
    late TestSkill testSkill;
    late GamePlayer player;
    late GameState gameState;

    setUp(() {
      testSkill = TestSkill();

      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      player = AIPlayer(
        id: 'test_player',
        name: '测试玩家',
        index: 1,
        role: WerewolfRole(),
        intelligence: intelligence,
      );

      gameState = GameState(
        gameId: 'test_game',
        scenario: Scenario9Players(),
        players: [player],
        dayNumber: 1,
        currentPhase: GamePhase.night,
      );
    });

    test('GameSkill基本属性测试', () {
      expect(testSkill.skillId, equals('test_skill'));
      expect(testSkill.name, equals('测试技能'));
      expect(testSkill.description, isNotEmpty);
      expect(testSkill.priority, equals(50));
      expect(testSkill.prompt, isNotEmpty);
    });

    test('技能施放条件测试', () {
      // 正常情况下可以施放
      expect(testSkill.canCast(player, gameState), isTrue);

      // 玩家死亡时不能施放
      player.setAlive(false);
      expect(testSkill.canCast(player, gameState), isFalse);

      // 恢复生命
      player.setAlive(true);
      expect(testSkill.canCast(player, gameState), isTrue);
    });

    test('技能施放成功测试', () async {
      final result = await testSkill.cast(player, gameState);

      expect(result.success, isTrue);
      expect(result.caster, equals(player));
      expect(result.metadata['skillId'], equals('test_skill'));
    });

    test('技能施放失败测试', () async {
      // 设置技能为失败模式
      testSkill.shouldFail = true;

      final result = await testSkill.cast(player, gameState);

      expect(result.success, isFalse);
      expect(result.caster, equals(player));
    });
  });

  group('夜晚技能测试', () {
    late WerewolfKillSkill werewolfKill;
    late GuardProtectSkill guardProtect;
    late GamePlayer werewolf;
    late GamePlayer guard;
    late GamePlayer villager;
    late GameState nightState;

    setUp(() {
      werewolfKill = WerewolfKillSkill();
      guardProtect = GuardProtectSkill();

      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      werewolf = AIPlayer(
        id: 'werewolf',
        name: '狼人',
        index: 1,
        role: WerewolfRole(),
        intelligence: intelligence,
      );

      guard = AIPlayer(
        id: 'guard',
        name: '守卫',
        index: 2,
        role: GuardRole(),
        intelligence: intelligence,
      );

      villager = AIPlayer(
        id: 'villager',
        name: '村民',
        index: 3,
        role: VillagerRole(),
        intelligence: intelligence,
      );

      nightState = GameState(
        gameId: 'test_night_game',
        scenario: Scenario9Players(),
        players: [werewolf, guard, villager],
        dayNumber: 1,
        currentPhase: GamePhase.night,
      );
    });

    test('狼人击杀技能属性测试', () {
      expect(werewolfKill.skillId, equals('werewolf_kill'));
      expect(werewolfKill.name, equals('狼人击杀'));
      expect(werewolfKill.priority, equals(100));
      expect(werewolfKill.prompt, contains('夜晚阶段'));
      expect(werewolfKill.prompt, contains('击杀目标'));
    });

    test('狼人击杀技能施放条件测试', () {
      // 狼人在夜晚可以施放
      expect(werewolfKill.canCast(werewolf, nightState), isTrue);

      // 非狼人不能施放
      expect(werewolfKill.canCast(guard, nightState), isFalse);
      expect(werewolfKill.canCast(villager, nightState), isFalse);

      // 白天不能施放
      final dayState = GameState(
        gameId: 'test_day_game',
        scenario: Scenario9Players(),
        players: [werewolf, guard, villager],
        dayNumber: 1,
        currentPhase: GamePhase.day,
      );
      expect(werewolfKill.canCast(werewolf, dayState), isFalse);

      // 死亡的狼人不能施放
      werewolf.setAlive(false);
      expect(werewolfKill.canCast(werewolf, nightState), isFalse);
    });

    test('狼人击杀技能执行测试', () async {
      final result = await werewolfKill.cast(werewolf, nightState);

      expect(result.success, isTrue);
      expect(result.caster, equals(werewolf));
      expect(result.metadata['skillId'], equals('werewolf_kill'));
      expect(result.metadata['skillType'], equals('werewolf_kill'));
      expect(result.metadata['availableTargets'], equals(2)); // guard和villager
    });

    test('守卫保护技能属性测试', () {
      expect(guardProtect.skillId, equals('guard_protect'));
      expect(guardProtect.name, equals('守卫保护'));
      expect(guardProtect.priority, equals(90));
      expect(guardProtect.prompt, contains('守护'));
    });

    test('守卫保护技能施放条件测试', () {
      // 守卫在夜晚可以施放
      expect(guardProtect.canCast(guard, nightState), isTrue);

      // 非守卫不能施放
      expect(guardProtect.canCast(werewolf, nightState), isFalse);
      expect(guardProtect.canCast(villager, nightState), isFalse);
    });
  });

  group('技能优先级排序测试', () {
    late List<GameSkill> skills;

    setUp(() {
      skills = [
        TestSkill(priority: 50),
        WerewolfKillSkill(), // priority 100
        GuardProtectSkill(), // priority 90
        TestSkill(priority: 30),
        TestSkill(priority: 80),
      ];
    });

    test('技能按优先级正确排序', () {
      // 按优先级从高到低排序
      skills.sort((a, b) => b.priority.compareTo(a.priority));

      expect(skills[0].priority, equals(100)); // WerewolfKillSkill
      expect(skills[1].priority, equals(90)); // GuardProtectSkill
      expect(skills[2].priority, equals(80)); // TestSkill
      expect(skills[3].priority, equals(50)); // TestSkill
      expect(skills[4].priority, equals(30)); // TestSkill

      // 验证技能ID
      expect(skills[0].skillId, equals('werewolf_kill'));
      expect(skills[1].skillId, equals('guard_protect'));
    });

    test('同优先级技能保持稳定排序', () {
      final skill1 = TestSkill(priority: 50, suffix: '_1');
      final skill2 = TestSkill(priority: 50, suffix: '_2');
      final skill3 = TestSkill(priority: 50, suffix: '_3');

      final testSkills = [skill3, skill1, skill2];
      testSkills.sort((a, b) => b.priority.compareTo(a.priority));

      // 同优先级时应保持原有顺序
      expect(testSkills[0], equals(skill3));
      expect(testSkills[1], equals(skill1));
      expect(testSkills[2], equals(skill2));
    });
  });

  group('SkillProcessor冲突处理测试', () {
    late SkillProcessor processor;
    late GameState gameState;
    late GamePlayer werewolf;
    late GamePlayer guard;
    late GamePlayer villager;

    setUp(() {
      processor = SkillProcessor();

      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      werewolf = AIPlayer(
        id: 'werewolf',
        name: '狼人',
        index: 1,
        role: WerewolfRole(),
        intelligence: intelligence,
      );

      guard = AIPlayer(
        id: 'guard',
        name: '守卫',
        index: 2,
        role: GuardRole(),
        intelligence: intelligence,
      );

      villager = AIPlayer(
        id: 'villager',
        name: '村民',
        index: 3,
        role: VillagerRole(),
        intelligence: intelligence,
      );

      gameState = GameState(
        gameId: 'test_processor_game',
        scenario: Scenario9Players(),
        players: [werewolf, guard, villager],
        dayNumber: 1,
        currentPhase: GamePhase.night,
      );
    });

    test('空技能结果列表处理', () async {
      // 空列表不应该抛出异常
      expect(() => processor.process([], gameState), returnsNormally);
    });

    test('保护vs击杀冲突处理', () async {
      final killResult = SkillResult.success(
        caster: werewolf,
        target: villager,
        metadata: {'skillId': 'werewolf_kill', 'skillType': 'kill'},
      );

      final protectResult = SkillResult.success(
        caster: guard,
        target: villager,
        metadata: {'skillId': 'guard_protect', 'skillType': 'protect'},
      );

      final results = [killResult, protectResult];

      // 处理冲突不应该抛出异常
      expect(() => processor.process(results, gameState), returnsNormally);
    });

    test('治疗vs击杀冲突处理', () async {
      final killResult = SkillResult.success(
        caster: werewolf,
        target: villager,
        metadata: {'skillId': 'werewolf_kill', 'skillType': 'kill'},
      );

      final healResult = SkillResult.success(
        caster: guard, // 假设守卫有治疗能力
        target: villager,
        metadata: {'skillId': 'witch_heal', 'skillType': 'heal'},
      );

      final results = [killResult, healResult];

      // 处理冲突不应该抛出异常
      expect(() => processor.process(results, gameState), returnsNormally);
    });

    test('多重冲突处理', () async {
      // 同一目标同时被击杀、保护和治疗
      final killResult = SkillResult.success(
        caster: werewolf,
        target: villager,
        metadata: {'skillId': 'werewolf_kill'},
      );

      final protectResult = SkillResult.success(
        caster: guard,
        target: villager,
        metadata: {'skillId': 'guard_protect'},
      );

      final healResult = SkillResult.success(
        caster: guard,
        target: villager,
        metadata: {'skillId': 'witch_heal'},
      );

      final results = [killResult, protectResult, healResult];

      // 复杂冲突处理不应该抛出异常
      expect(() => processor.process(results, gameState), returnsNormally);
    });
  });
}

// 测试用的技能实现
class TestSkill extends GameSkill {
  final int _priority;
  final String _suffix;
  bool shouldFail = false;

  TestSkill({int priority = 50, String suffix = ''})
    : _priority = priority,
      _suffix = suffix;

  @override
  String get skillId => 'test_skill$_suffix';

  @override
  String get name => '测试技能';

  @override
  String get description => '用于测试的技能';

  @override
  int get priority => _priority;

  @override
  String get prompt => '这是一个测试技能的提示词';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    if (shouldFail) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'reason': 'Test failure'},
      );
    }

    return SkillResult.success(
      caster: player,
      metadata: {'skillId': skillId, 'test': true},
    );
  }
}
