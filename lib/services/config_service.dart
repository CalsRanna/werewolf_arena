import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/domain/value_objects/config_loader.dart';
import 'package:werewolf_arena/engine/drivers/ai_player_driver.dart';
import 'package:werewolf_arena/engine/scenarios/game_scenario.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_9_players.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_12_players.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/ai_player.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role_factory.dart';

/// 配置服务 - v2.0.0架构的Flutter友好包装层
///
/// 提供Flutter UI层访问新架构配置系统的便捷接口
class ConfigService {
  GameConfig? _gameConfig;
  String? _currentScenarioId;
  bool _isInitialized = false;

  // 静态场景映射
  static final Map<String, GameScenario> _scenarios = {
    '9_players': Scenario9Players(),
    '12_players': Scenario12Players(),
  };

  /// 确保配置已初始化
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    try {
      // 尝试加载配置文件，失败则使用默认配置
      _gameConfig = await ConfigLoader.loadDefaultConfig();
    } catch (e) {
      // 如果加载失败，创建一个基本的默认配置
      _gameConfig = GameConfig(
        playerIntelligences: List.generate(
          12,
          (index) => PlayerIntelligence(
            baseUrl: 'https://api.openai.com/v1',
            apiKey: 'your-api-key-${index + 1}',
            modelId: 'gpt-4',
          ),
        ),
        maxRetries: 3,
      );
    }

    // 设置默认场景
    _currentScenarioId = '9_players';
    _isInitialized = true;
  }

  /// 获取当前游戏配置
  GameConfig get gameConfig {
    _ensureInitialized();
    return _gameConfig!;
  }

  /// 获取当前场景
  GameScenario? get currentScenario {
    _ensureInitialized();
    return _currentScenarioId != null ? _scenarios[_currentScenarioId] : null;
  }

  /// 获取当前场景名称
  String get currentScenarioName {
    final scenario = currentScenario;
    return scenario?.name ?? '未设置场景';
  }

  /// 设置当前场景
  Future<void> setScenario(String scenarioId) async {
    await ensureInitialized();
    if (_scenarios.containsKey(scenarioId)) {
      _currentScenarioId = scenarioId;
    } else {
      throw ArgumentError('未知的场景ID: $scenarioId');
    }
  }

  /// 自动选择场景
  Future<void> autoSelectScenario(int playerCount) async {
    await ensureInitialized();

    final suitableScenarios = _scenarios.values
        .where((scenario) => scenario.playerCount == playerCount)
        .toList();

    if (suitableScenarios.isEmpty) {
      throw Exception('没有找到适合 $playerCount 人的场景');
    }

    _currentScenarioId = suitableScenarios.first.id;
  }

  /// 获取所有可用场景
  List<GameScenario> get availableScenarios {
    _ensureInitialized();
    return _scenarios.values.toList();
  }

  /// 获取指定玩家数量的可用场景
  List<GameScenario> getAvailableScenarios(int playerCount) {
    _ensureInitialized();
    return _scenarios.values
        .where((scenario) => scenario.playerCount == playerCount)
        .toList();
  }

  /// 为场景创建玩家列表
  List<GamePlayer> createGamePlayersForScenario(GameScenario scenario) {
    _ensureInitialized();

    final players = <GamePlayer>[];
    final roleTypes = scenario.getExpandedGameRoles();

    // 随机打乱角色顺序
    final shuffledRoles = List<RoleType>.from(roleTypes);
    shuffledRoles.shuffle();

    for (int i = 0; i < shuffledRoles.length; i++) {
      final playerNumber = i + 1;
      final playerName = '$playerNumber号玩家';
      final roleType = shuffledRoles[i];

      // 创建角色实例
      final role = GameRoleFactory.createRoleFromType(roleType);

      // 获取玩家的智能配置
      final intelligence =
          _gameConfig!.getPlayerIntelligence(playerNumber) ??
          _gameConfig!.defaultIntelligence!;

      // 创建AI玩家
      final player = AIPlayer(
        id: playerName,
        name: playerName,
        index: playerNumber,
        role: role,
        driver: AIPlayerDriver(intelligence: intelligence),
      );

      players.add(player);
    }

    return players;
  }

  /// 更新玩家智能配置
  void updatePlayerIntelligence(
    int playerNumber,
    PlayerIntelligence intelligence,
  ) {
    _ensureInitialized();

    if (playerNumber < 1 ||
        playerNumber > _gameConfig!.playerIntelligences.length) {
      throw ArgumentError('无效的玩家编号: $playerNumber');
    }

    // 创建新的配置实例（因为GameConfig是不可变的）
    final newIntelligences = List<PlayerIntelligence>.from(
      _gameConfig!.playerIntelligences,
    );
    newIntelligences[playerNumber - 1] = intelligence;

    _gameConfig = GameConfig(
      playerIntelligences: newIntelligences,
      maxRetries: _gameConfig!.maxRetries,
    );
  }

  /// 获取玩家数量限制
  int get minPlayers => 6;
  int get maxPlayers => 15;

  /// 检查玩家数量是否有效
  bool isValidPlayerCount(int count) =>
      count >= minPlayers && count <= maxPlayers;

  /// 兼容性属性：为了保持UI层兼容性
  /// @deprecated 使用gameConfig替代
  @Deprecated('使用gameConfig属性替代')
  dynamic get appConfig {
    // 返回一个包含基本配置信息的对象
    return _MockAppConfig(gameConfig);
  }

  /// 兼容性属性：为了保持UI层兼容性
  /// @deprecated 新架构中不再需要GameParameters
  @Deprecated('新架构中不再需要GameParameters')
  dynamic get gameParameters {
    return _MockGameParameters();
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized || _gameConfig == null) {
      throw StateError('ConfigService未初始化,请先调用ensureInitialized()');
    }
  }

  /// 重置配置
  Future<void> reset() async {
    _gameConfig = null;
    _currentScenarioId = null;
    _isInitialized = false;
    await ensureInitialized();
  }
}

/// Mock类：为了保持与旧AppConfig的兼容性
class _MockAppConfig {
  final GameConfig _gameConfig;

  _MockAppConfig(this._gameConfig);

  // 提供旧UI层期望的属性
  dynamic get defaultLLM => _gameConfig.defaultIntelligence;
  dynamic get playerModels => _gameConfig.playerIntelligences;
}

/// Mock类：为了保持与旧GameParameters的兼容性
class _MockGameParameters {
  _MockGameParameters();

  // 提供旧UI层期望的方法
  Future<void> saveConfig(dynamic newConfig) async {
    // 在新架构中，配置保存逻辑需要重新设计
    // 这里提供一个空实现以保持兼容性
  }
}
