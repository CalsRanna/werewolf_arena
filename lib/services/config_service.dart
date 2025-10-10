import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/rules/game_scenario.dart';
import 'package:werewolf_arena/core/rules/game_scenario_manager.dart';
import 'package:werewolf_arena/core/entities/player/player.dart';
import 'package:werewolf_arena/core/entities/player/ai_player.dart';
import 'package:werewolf_arena/services/llm/llm_service.dart';
import 'package:werewolf_arena/services/llm/prompt_manager.dart';

/// 配置服务 - Flutter友好的包装层
class ConfigService {
  bool _isInitialized = false;
  ConfigManager? _configManager;

  /// 确保配置已初始化
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    _configManager = GUIConfigManager.instance;
    await _configManager!.initialize();

    // 设置默认场景(如果还没有设置)
    if (_configManager!.currentScenario == null) {
      final availableScenarios = _configManager!.scenarioManager.scenarios.values.toList();
      if (availableScenarios.isNotEmpty) {
        _configManager!.setCurrentScenario(availableScenarios.first.id);
      }
    }

    _isInitialized = true;
  }

  /// 获取当前场景名称
  String get currentScenarioName {
    _ensureInitialized();
    return _configManager!.currentScenario?.name ?? '未设置场景';
  }

  /// 获取当前场景
  GameScenario? get currentScenario {
    _ensureInitialized();
    return _configManager!.currentScenario;
  }

  /// 设置场景
  Future<void> setScenario(String scenarioId) async {
    await ensureInitialized();
    _configManager!.setCurrentScenario(scenarioId);
  }

  /// 自动选择场景
  Future<void> autoSelectScenario(int playerCount) async {
    await ensureInitialized();
    final scenarios = _configManager!.getAvailableScenarios(playerCount);
    if (scenarios.isEmpty) {
      throw Exception('没有找到适合 $playerCount 人的场景');
    }
    _configManager!.setCurrentScenario(scenarios.first.id);
  }

  /// 获取所有可用的场景
  List<GameScenario> get availableScenarios {
    _ensureInitialized();
    return _configManager!.scenarioManager.scenarios.values.toList();
  }

  /// 获取指定玩家数量的可用场景
  List<GameScenario> getAvailableScenarios(int playerCount) {
    _ensureInitialized();
    return _configManager!.getAvailableScenarios(playerCount);
  }

  /// 为场景创建玩家
  List<Player> createPlayersForScenario(GameScenario scenario) {
    _ensureInitialized();

    final players = <Player>[];
    final roleIds = scenario.getExpandedRoles();
    roleIds.shuffle();  // 随机打乱角色顺序

    for (int i = 0; i < roleIds.length; i++) {
      final playerNumber = i + 1;
      final playerName = '${playerNumber}号玩家';
      final roleId = roleIds[i];
      final role = scenario.createRole(roleId);

      // 获取玩家专属的LLM配置
      final playerLLMConfig = _configManager!.getPlayerLLMConfig(playerNumber);
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
    return _configManager!.config;
  }

  /// 获取场景管理器
  ScenarioManager get scenarioManager {
    _ensureInitialized();
    return _configManager!.scenarioManager;
  }

  /// 获取ConfigManager实例
  ConfigManager? get configManager {
    return _configManager;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized || _configManager == null) {
      throw StateError('ConfigService未初始化,请先调用ensureInitialized()');
    }
  }
}
