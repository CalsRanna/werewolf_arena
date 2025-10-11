import 'package:werewolf_arena/core/domain/value_objects/player_model_config.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
// import 'package:werewolf_arena/core/scenarios/scenario_registry.dart'; // 已删除
import 'package:werewolf_arena/core/domain/entities/player.dart' hide AIPlayer;
import 'package:werewolf_arena/core/domain/entities/ai_player.dart';
import 'package:werewolf_arena/services/llm/llm_service.dart';
import 'package:werewolf_arena/services/llm/prompt_manager.dart';

/// 配置服务 - Flutter友好的包装层
class ConfigService {
  bool _isInitialized = false;
  FlutterGameParameters? _gameParameters;

  /// 确保配置已初始化
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    _gameParameters = FlutterGameParameters.instance;
    await _gameParameters!.initialize();

    // 设置默认场景(如果还没有设置)
    if (_gameParameters!.currentScenario == null) {
      // final availableScenarios = _gameParameters!
      //     .scenarioRegistry
      //     .scenarios
      //     .values
      //     .toList(); // 已删除
      // if (availableScenarios.isNotEmpty) {
      //   _gameParameters!.setCurrentScenario(availableScenarios.first.id);
      // }
      // 暂时跳过场景设置，等待阶段4重构
    }

    _isInitialized = true;
  }

  /// 获取当前场景名称
  String get currentScenarioName {
    _ensureInitialized();
    return _gameParameters!.currentScenario?.name ?? '未设置场景';
  }

  /// 获取当前场景
  GameScenario? get currentScenario {
    _ensureInitialized();
    return _gameParameters!.currentScenario;
  }

  /// 设置场景
  Future<void> setScenario(String scenarioId) async {
    await ensureInitialized();
    _gameParameters!.setCurrentScenario(scenarioId);
  }

  /// 自动选择场景
  Future<void> autoSelectScenario(int playerCount) async {
    await ensureInitialized();
    final scenarios = _gameParameters!.getAvailableScenarios(playerCount);
    if (scenarios.isEmpty) {
      throw Exception('没有找到适合 $playerCount 人的场景');
    }
    _gameParameters!.setCurrentScenario(scenarios.first.id);
  }

  /// 获取所有可用的场景
  List<GameScenario> get availableScenarios {
    _ensureInitialized();
    // return _gameParameters!.scenarioRegistry.scenarios.values.toList(); // 已删除
    throw UnimplementedError('availableScenarios 将在阶段4重构时恢复');
  }

  /// 获取指定玩家数量的可用场景
  List<GameScenario> getAvailableScenarios(int playerCount) {
    _ensureInitialized();
    return _gameParameters!.getAvailableScenarios(playerCount);
  }

  /// 为场景创建玩家
  List<Player> createPlayersForScenario(GameScenario scenario) {
    _ensureInitialized();

    final players = <Player>[];
    final roleIds = scenario.getExpandedRoles();
    roleIds.shuffle(); // 随机打乱角色顺序

    for (int i = 0; i < roleIds.length; i++) {
      final playerNumber = i + 1;
      final playerName = '${playerNumber}号玩家';
      final roleId = roleIds[i];
      final role = scenario.createRole(roleId);

      // 获取玩家专属的LLM配置
      final playerLLMConfig = _gameParameters!.getPlayerLLMConfig(playerNumber);
      final playerModelConfig = PlayerModelConfig.fromMap(playerLLMConfig);

      // 创建LLM服务和Prompt管理器
      final llmService = OpenAIService.fromPlayerConfig(playerModelConfig);
      final promptManager = PromptManager();

      // 创建AI玩家实例
      final player = AIPlayer(
        id: playerName,
        name: playerName,
        index: i,
        role: role,
        intelligence: PlayerIntelligence(
          baseUrl: playerModelConfig.baseUrl ?? 'https://api.openai.com',
          apiKey: playerModelConfig.apiKey,
          modelId: playerModelConfig.model,
        ),
      );

      players.add(player);
    }

    return players;
  }

  /// 获取应用配置
  AppConfig get appConfig {
    _ensureInitialized();
    return _gameParameters!.config;
  }

  /// 获取场景注册表
  // ScenarioRegistry get scenarioRegistry { // 已删除
  //   _ensureInitialized();
  //   return _gameParameters!.scenarioRegistry;
  // }
  
  @Deprecated('scenarioRegistry将在阶段4删除')
  dynamic get scenarioRegistry {
    throw UnimplementedError('scenarioRegistry已删除，将在阶段4重构时使用新架构');
  }

  /// 获取游戏参数实例
  FlutterGameParameters? get gameParameters {
    return _gameParameters;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized || _gameParameters == null) {
      throw StateError('ConfigService未初始化,请先调用ensureInitialized()');
    }
  }
}
