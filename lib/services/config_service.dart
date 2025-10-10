import 'package:werewolf_arena/core/domain/value_objects/player_model_config.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/core/scenarios/scenario_registry.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
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
      final availableScenarios = _gameParameters!
          .scenarioRegistry
          .scenarios
          .values
          .toList();
      if (availableScenarios.isNotEmpty) {
        _gameParameters!.setCurrentScenario(availableScenarios.first.id);
      }
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
    return _gameParameters!.scenarioRegistry.scenarios.values.toList();
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

      final player = EnhancedAIPlayer(
        name: playerName,
        role: role,
        llmService: llmService,
        promptManager: promptManager,
        modelConfig: playerModelConfig,
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
  ScenarioRegistry get scenarioRegistry {
    _ensureInitialized();
    return _gameParameters!.scenarioRegistry;
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
