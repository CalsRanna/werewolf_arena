import 'package:test/test.dart';
import 'package:werewolf_arena/engine/domain/entities/ai_player.dart';
import 'package:werewolf_arena/engine/domain/entities/human_player.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/entities/villager_role.dart';
import 'package:werewolf_arena/engine/domain/entities/werewolf_role.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_9_players.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

void main() {
  group('GamePlayer基础功能测试', () {
    late AIPlayer aiPlayer;
    late HumanPlayer humanPlayer;
    late PlayerIntelligence intelligence;
    late GameRole werewolfRole;
    late GameRole villagerRole;

    setUp(() {
      intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      werewolfRole = WerewolfRole();
      villagerRole = VillagerRole();

      aiPlayer = AIPlayer(
        id: 'ai_1',
        name: 'AI玩家1',
        index: 1,
        role: werewolfRole,
        intelligence: intelligence,
      );

      humanPlayer = HumanPlayer(
        id: 'human_1',
        name: '人类玩家1',
        index: 2,
        role: villagerRole,
      );
    });

    test('AIPlayer基本属性测试', () {
      expect(aiPlayer.id, equals('ai_1'));
      expect(aiPlayer.name, equals('AI玩家1'));
      expect(aiPlayer.index, equals(1));
      expect(aiPlayer.role, equals(werewolfRole));
      expect(aiPlayer.isAlive, isTrue);
      expect(aiPlayer.isProtected, isFalse);
      expect(aiPlayer.isSilenced, isFalse);
      expect(aiPlayer.isDead, isFalse);
    });

    test('HumanPlayer基本属性测试', () {
      expect(humanPlayer.id, equals('human_1'));
      expect(humanPlayer.name, equals('人类玩家1'));
      expect(humanPlayer.index, equals(2));
      expect(humanPlayer.role, equals(villagerRole));
      expect(humanPlayer.isAlive, isTrue);
      expect(humanPlayer.isProtected, isFalse);
      expect(humanPlayer.isSilenced, isFalse);
      expect(humanPlayer.isDead, isFalse);
    });

    test('角色相关属性测试', () {
      // 狼人玩家
      expect(aiPlayer.isWerewolf, isTrue);
      expect(aiPlayer.isVillager, isFalse);
      expect(aiPlayer.isGood, isFalse);
      expect(aiPlayer.isEvil, isTrue);

      // 村民玩家
      expect(humanPlayer.isWerewolf, isFalse);
      expect(humanPlayer.isVillager, isTrue);
      expect(humanPlayer.isGood, isTrue);
      expect(humanPlayer.isEvil, isFalse);
    });

    test('状态修改测试', () {
      // 测试死亡
      aiPlayer.setAlive(false);
      expect(aiPlayer.isAlive, isFalse);
      expect(aiPlayer.isDead, isTrue);

      // 恢复生命（测试用）
      aiPlayer.setAlive(true);
      expect(aiPlayer.isAlive, isTrue);
      expect(aiPlayer.isDead, isFalse);

      // 测试保护状态
      aiPlayer.setProtected(true);
      expect(aiPlayer.isProtected, isTrue);
      aiPlayer.setProtected(false);
      expect(aiPlayer.isProtected, isFalse);

      // 测试沉默状态
      aiPlayer.setSilenced(true);
      expect(aiPlayer.isSilenced, isTrue);
      aiPlayer.setSilenced(false);
      expect(aiPlayer.isSilenced, isFalse);
    });

    test('行动能力测试', () {
      // 活着的玩家在任何阶段都能行动
      expect(aiPlayer.canAct(GamePhase.night), isTrue);
      expect(aiPlayer.canAct(GamePhase.day), isTrue);

      // 死亡的玩家不能行动
      aiPlayer.setAlive(false);
      expect(aiPlayer.canAct(GamePhase.night), isFalse);
      expect(aiPlayer.canAct(GamePhase.day), isFalse);

      // 恢复生命
      aiPlayer.setAlive(true);

      // 沉默的玩家在白天不能行动
      aiPlayer.setSilenced(true);
      expect(aiPlayer.canAct(GamePhase.night), isTrue); // 夜晚可以
      expect(aiPlayer.canAct(GamePhase.day), isFalse); // 白天不可以

      aiPlayer.setSilenced(false);
    });

    test('投票和发言能力测试', () {
      // 正常状态下可以投票和发言
      expect(aiPlayer.canVote(), isTrue);
      expect(aiPlayer.canSpeak(), isTrue);

      // 死亡后不能投票和发言
      aiPlayer.setAlive(false);
      expect(aiPlayer.canVote(), isFalse);
      expect(aiPlayer.canSpeak(), isFalse);

      // 恢复生命
      aiPlayer.setAlive(true);

      // 沉默后不能投票和发言
      aiPlayer.setSilenced(true);
      expect(aiPlayer.canVote(), isFalse);
      expect(aiPlayer.canSpeak(), isFalse);

      aiPlayer.setSilenced(false);
    });

    test('私有数据管理测试', () {
      // 设置和获取私有数据
      aiPlayer.setPrivateData('test_key', 'test_value');
      expect(aiPlayer.getPrivateData<String>('test_key'), equals('test_value'));
      expect(aiPlayer.hasPrivateData('test_key'), isTrue);

      // 设置不同类型的数据
      aiPlayer.setPrivateData('number', 42);
      aiPlayer.setPrivateData('bool', true);
      expect(aiPlayer.getPrivateData<int>('number'), equals(42));
      expect(aiPlayer.getPrivateData<bool>('bool'), isTrue);

      // 移除数据
      aiPlayer.removePrivateData('test_key');
      expect(aiPlayer.hasPrivateData('test_key'), isFalse);
      expect(aiPlayer.getPrivateData<String>('test_key'), isNull);
    });

    test('知识管理测试', () {
      // 添加和获取知识
      aiPlayer.addKnowledge('seer_result', {
        'player': 'Player2',
        'result': 'Good',
      });
      expect(aiPlayer.hasKnowledge('seer_result'), isTrue);

      final seerResult = aiPlayer.getKnowledge<Map<String, dynamic>>(
        'seer_result',
      );
      expect(seerResult, isNotNull);
      expect(seerResult!['player'], equals('Player2'));
      expect(seerResult['result'], equals('Good'));

      // 不存在的知识
      expect(aiPlayer.hasKnowledge('nonexistent'), isFalse);
      expect(aiPlayer.getKnowledge('nonexistent'), isNull);
    });

    test('技能使用次数管理测试', () {
      // 初始状态下技能使用次数为0
      expect(aiPlayer.getSkillUses('heal'), equals(0));
      expect(aiPlayer.getSkillUses('poison'), equals(0));

      // 使用技能
      aiPlayer.useSkill('heal');
      expect(aiPlayer.getSkillUses('heal'), equals(1));
      expect(aiPlayer.getSkillUses('poison'), equals(0));

      // 多次使用同一技能
      aiPlayer.useSkill('heal');
      expect(aiPlayer.getSkillUses('heal'), equals(2));

      // 使用不同技能
      aiPlayer.useSkill('poison');
      expect(aiPlayer.getSkillUses('poison'), equals(1));
    });

    test('死亡处理测试', () {
      final gameState = GameState(
        gameId: 'test_game',
        scenario: Scenario9Players(),
        players: [aiPlayer],
        dayNumber: 1,
      );

      // 测试死亡
      aiPlayer.die(DeathCause.werewolfKill, gameState);
      expect(aiPlayer.isAlive, isFalse);
      expect(
        aiPlayer.getPrivateData('death_cause'),
        equals(DeathCause.werewolfKill),
      );
    });

    test('阶段变化处理测试', () {
      // 测试阶段变化
      aiPlayer.onPhaseChange(GamePhase.day, GamePhase.night);
      expect(aiPlayer.getPrivateData('last_phase'), equals(GamePhase.day));
      expect(aiPlayer.getPrivateData('current_phase'), equals(GamePhase.night));

      // 夜晚阶段应该重置保护和沉默状态
      aiPlayer.setProtected(true);
      aiPlayer.setSilenced(true);
      aiPlayer.onPhaseChange(GamePhase.day, GamePhase.night);
      expect(aiPlayer.isProtected, isFalse);
      expect(aiPlayer.isSilenced, isFalse);
    });

    test('toString方法测试', () {
      expect(aiPlayer.toString(), equals('AI玩家1 (${werewolfRole.name})'));
      expect(humanPlayer.toString(), equals('人类玩家1 (${villagerRole.name})'));
    });

    test('formattedName属性测试', () {
      expect(aiPlayer.formattedName, isNotEmpty);
      expect(humanPlayer.formattedName, isNotEmpty);
      // formattedName应该包含玩家名称
      expect(aiPlayer.formattedName, contains('AI玩家1'));
      expect(humanPlayer.formattedName, contains('人类玩家1'));
    });
  });

  group('HumanPlayer特有功能测试', () {
    late HumanPlayer humanPlayer;
    late GameRole villagerRole;

    setUp(() {
      villagerRole = VillagerRole();
      humanPlayer = HumanPlayer(
        id: 'human_test',
        name: '测试人类',
        index: 1,
        role: villagerRole,
      );
    });

    test('技能结果提交测试', () async {
      final skillResult = SkillResult(
        caster: humanPlayer,
        target: humanPlayer,
        reasoning: 'test',
      );

      // 提交技能结果（不会阻塞，因为是broadcast stream）
      humanPlayer.submitSkillResult(skillResult);

      // 验证可以正常调用（具体的stream监听需要在实际游戏逻辑中测试）
      expect(() => humanPlayer.submitSkillResult(skillResult), returnsNormally);
    });

    test('取消技能输入测试', () {
      // 取消技能输入不应该抛出异常
      expect(() => humanPlayer.cancelSkillInput(), returnsNormally);
    });
  });

  group('技能执行测试', () {
    late AIPlayer aiPlayer;
    late GameState gameState;
    late MockSkill mockSkill;

    setUp(() {
      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      aiPlayer = AIPlayer(
        id: 'ai_test',
        name: 'AI测试',
        index: 1,
        role: WerewolfRole(),
        intelligence: intelligence,
      );

      gameState = GameState(
        gameId: 'test_game',
        scenario: Scenario9Players(),
        players: [aiPlayer],
        dayNumber: 1,
      );
      mockSkill = MockSkill();
    });

    test('技能执行失败 - 无法施放', () async {
      // 设置技能为无法施放
      mockSkill.canCastResult = false;

      final result = await aiPlayer.executeSkill(mockSkill, gameState);
      expect(result?.reasoning, equals('Cannot cast skill'));
    });

    test('技能执行成功', () async {
      // 设置技能为可施放
      mockSkill.canCastResult = true;
      mockSkill.castResult = SkillResult(
        caster: aiPlayer,
        target: aiPlayer,
        reasoning: 'test',
      );

      final result = await aiPlayer.executeSkill(mockSkill, gameState);
      expect(result?.reasoning, equals('test'));
    });
  });

  group('Driver集成测试', () {
    test('AIPlayer应该有AIPlayerDriver', () {
      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-3.5-turbo',
      );

      final aiPlayer = AIPlayer(
        id: 'ai_driver_test',
        name: 'AI Driver测试',
        index: 1,
        role: WerewolfRole(),
        intelligence: intelligence,
      );

      expect(aiPlayer.driver, isNotNull);
      expect(
        aiPlayer.driver.runtimeType.toString(),
        contains('AIPlayerDriver'),
      );
    });

    test('HumanPlayer应该有HumanPlayerDriver', () {
      final humanPlayer = HumanPlayer(
        id: 'human_driver_test',
        name: 'Human Driver测试',
        index: 1,
        role: VillagerRole(),
      );

      expect(humanPlayer.driver, isNotNull);
      expect(
        humanPlayer.driver.runtimeType.toString(),
        contains('HumanPlayerDriver'),
      );
    });
  });
}

// Mock类用于测试
class MockSkill extends GameSkill {
  bool canCastResult = true;
  SkillResult? castResult;

  @override
  String get skillId => 'mock_skill';

  @override
  String get name => 'Mock Skill';

  @override
  String get description => 'A mock skill for testing';

  @override
  int get priority => 5;

  @override
  String get prompt => 'Mock skill prompt';

  @override
  bool canCast(dynamic player, GameState state) => canCastResult;

  @override
  Future<SkillResult> cast(
    dynamic player,
    GameState state, {
    Map<String, dynamic>? aiResponse,
  }) async {
    return castResult ??
        SkillResult(caster: player, target: player, reasoning: 'test');
  }
}
