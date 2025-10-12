import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/domain/value_objects/config_loader.dart';
import 'package:werewolf_arena/engine/scenarios/game_scenario.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_9_players.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_12_players.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/ai_player.dart';
import 'package:werewolf_arena/engine/domain/entities/human_player.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role_factory.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/game_random.dart';

/// 游戏组装器 - 负责外部逻辑：配置加载、场景选择、玩家创建
///
/// 根据设计文档，GameAssembler 负责：
/// 1. 外部逻辑：加载配置
/// 2. 外部逻辑：选择场景
/// 3. 外部逻辑：创建玩家
/// 4. 创建游戏引擎
class GameAssembler {
  /// 组装完整的游戏
  ///
  /// 参数：
  /// - [configPath]: 配置文件路径（可选，默认加载默认配置）
  /// - [scenarioId]: 场景ID（可选，根据玩家数量自动选择）
  /// - [playerCount]: 玩家数量（可选，从场景推断）
  /// - [observer]: 游戏观察者（可选）
  ///
  /// 返回：配置完整的GameEngine实例
  static Future<GameEngine> assembleGame({
    String? configPath,
    String? scenarioId,
    int? playerCount,
    GameObserver? observer,
  }) async {
    // 1. 外部逻辑：加载配置
    final config = await _loadConfig(configPath);

    // 2. 外部逻辑：选择场景
    final scenario = await _selectScenario(scenarioId, playerCount);

    // 3. 外部逻辑：创建玩家
    final gamePlayers = await _createGamePlayers(scenario, config);

    // 4. 创建游戏引擎（只需要4个参数）
    return GameEngine(
      config: config,
      scenario: scenario,
      players: gamePlayers,
      observer: observer,
    );
  }

  /// 加载游戏配置
  ///
  /// 根据设计文档，配置系统已简化为GameConfig，只包含：
  /// - playerIntelligences: 玩家智能配置列表
  /// - maxRetries: 最大重试次数
  static Future<GameConfig> _loadConfig(String? configPath) async {
    try {
      if (configPath != null) {
        // 从指定路径加载配置
        return await ConfigLoader.loadFromFile(configPath);
      } else {
        // 加载默认配置
        return await ConfigLoader.loadDefaultConfig();
      }
    } catch (e) {
      // 配置加载失败时使用最小化默认配置
      return _createMinimalConfig();
    }
  }

  /// 创建最小化配置（当配置加载失败时使用）
  static GameConfig _createMinimalConfig() {
    return GameConfig(
      playerIntelligences: [
        // 提供一个默认的智能配置
        PlayerIntelligence(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'default-key', // 实际使用时需要真实的API密钥
          modelId: 'gpt-3.5-turbo',
        ),
      ],
      maxRetries: 3,
    );
  }

  /// 选择游戏场景
  ///
  /// 根据设计文档，场景选择逻辑：
  /// 1. 如果指定了scenarioId，直接使用
  /// 2. 如果指定了playerCount，根据人数选择
  /// 3. 默认使用9人局
  static Future<GameScenario> _selectScenario(
    String? scenarioId,
    int? playerCount,
  ) async {
    // 根据scenarioId选择
    if (scenarioId != null) {
      return _getScenarioById(scenarioId);
    }

    // 根据playerCount选择
    if (playerCount != null) {
      return _getScenarioByPlayerCount(playerCount);
    }

    // 默认返回9人局
    return Scenario9Players();
  }

  /// 根据ID获取场景
  static GameScenario _getScenarioById(String scenarioId) {
    switch (scenarioId) {
      case 'standard_9_players':
      case '9_players':
        return Scenario9Players();
      case 'standard_12_players':
      case '12_players':
        return Scenario12Players();
      default:
        throw ArgumentError('未知的场景ID: $scenarioId');
    }
  }

  /// 根据玩家数量获取场景
  static GameScenario _getScenarioByPlayerCount(int playerCount) {
    switch (playerCount) {
      case 9:
        return Scenario9Players();
      case 12:
        return Scenario12Players();
      default:
        throw ArgumentError('不支持的玩家数量: $playerCount，目前支持9人或12人');
    }
  }

  /// 创建游戏玩家列表
  ///
  /// 根据设计文档：
  /// 1. 根据场景配置创建玩家列表
  /// 2. 实现角色分配逻辑
  /// 3. 实现Driver配置逻辑
  /// 4. 每个玩家有自己的Driver实例
  static Future<List<GamePlayer>> _createGamePlayers(
    GameScenario scenario,
    GameConfig config,
  ) async {
    final players = <GamePlayer>[];
    final random = GameRandom();

    // 获取角色列表并随机分配
    final roleTypes = scenario.getExpandedGameRoles();
    roleTypes.shuffle(random.generator);

    // 创建玩家
    for (int i = 0; i < scenario.playerCount; i++) {
      final playerIndex = i + 1; // 玩家编号从1开始
      final roleType = roleTypes[i];
      final role = GameRoleFactory.createRoleFromType(roleType);

      // 获取玩家的智能配置
      final intelligence = _getPlayerIntelligence(config, playerIndex);

      // 根据配置创建AI玩家或人类玩家
      // 目前默认都创建AI玩家，后续可扩展支持混合模式
      final player = AIPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: role,
        intelligence: intelligence,
      );

      players.add(player);
    }

    return players;
  }

  /// 获取指定玩家的智能配置
  ///
  /// 根据设计文档：
  /// - playerIntelligences数组按玩家索引存储，1号玩家对应index 0
  /// - 如果没有为特定玩家配置智能，使用默认智能（第一个玩家的配置）
  static PlayerIntelligence _getPlayerIntelligence(
    GameConfig config,
    int playerIndex,
  ) {
    // 尝试获取指定玩家的智能配置
    final intelligence = config.getPlayerIntelligence(playerIndex);
    if (intelligence != null) {
      return intelligence;
    }

    // 使用默认智能配置
    final defaultIntelligence = config.defaultIntelligence;
    if (defaultIntelligence != null) {
      return defaultIntelligence;
    }

    // 如果没有任何配置，创建一个默认配置
    return PlayerIntelligence(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'default-key',
      modelId: 'gpt-3.5-turbo',
    );
  }

  /// 创建混合模式玩家（AI + 人类）
  ///
  /// 扩展方法：支持创建包含人类玩家的游戏
  /// - [humanPlayerIndices]: 人类玩家的索引列表（1-based）
  static Future<List<GamePlayer>> createMixedPlayers(
    GameScenario scenario,
    GameConfig config,
    List<int> humanPlayerIndices,
  ) async {
    final players = <GamePlayer>[];
    final random = GameRandom();

    // 获取角色列表并随机分配
    final roleTypes = scenario.getExpandedGameRoles();
    roleTypes.shuffle(random.generator);

    // 创建玩家
    for (int i = 0; i < scenario.playerCount; i++) {
      final playerIndex = i + 1; // 玩家编号从1开始
      final roleType = roleTypes[i];
      final role = GameRoleFactory.createRoleFromType(roleType);

      GamePlayer player;

      if (humanPlayerIndices.contains(playerIndex)) {
        // 创建人类玩家
        player = HumanPlayer(
          id: 'human_player_$playerIndex',
          name: '$playerIndex号玩家(人类)',
          index: playerIndex,
          role: role,
        );
      } else {
        // 创建AI玩家
        final intelligence = _getPlayerIntelligence(config, playerIndex);
        player = AIPlayer(
          id: 'ai_player_$playerIndex',
          name: '$playerIndex号玩家(AI)',
          index: playerIndex,
          role: role,
          intelligence: intelligence,
        );
      }

      players.add(player);
    }

    return players;
  }

  /// 获取可用场景列表
  ///
  /// 实用方法：获取所有支持的游戏场景
  static List<GameScenario> getAvailableScenarios() {
    return [Scenario9Players(), Scenario12Players()];
  }

  /// 验证配置
  ///
  /// 实用方法：验证配置是否有效
  static bool validateConfig(GameConfig config) {
    if (config.playerIntelligences.isEmpty) {
      return false;
    }

    if (config.maxRetries < 1) {
      return false;
    }

    // 验证每个智能配置是否有效
    for (final intelligence in config.playerIntelligences) {
      if (intelligence.apiKey.trim().isEmpty ||
          intelligence.baseUrl.trim().isEmpty ||
          intelligence.modelId.trim().isEmpty) {
        return false;
      }
    }

    return true;
  }

  /// 验证场景
  ///
  /// 实用方法：验证场景配置是否有效
  static bool validateScenario(GameScenario scenario) {
    if (scenario.playerCount < 3) {
      return false;
    }

    final roles = scenario.getExpandedGameRoles();
    if (roles.length != scenario.playerCount) {
      return false;
    }

    // 验证角色分配是否合理（至少要有狼人和好人）
    final hasWerewolf = roles.any((role) => role == RoleType.werewolf);
    final hasGoodGuy = roles.any((role) => role != RoleType.werewolf);

    return hasWerewolf && hasGoodGuy;
  }
}
