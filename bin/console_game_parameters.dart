import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/engine/game_scenario.dart';
import 'package:werewolf_arena/core/rules/game_scenario_manager.dart';
import 'package:werewolf_arena/core/engine/game_parameters.dart';

/// 控制台游戏参数实现（用于控制台应用）
///
/// 使用文件系统加载配置，不支持运行时保存。
/// 配置修改需要手动编辑 werewolf_config.yaml 文件。
///
/// 使用方式：
/// ```dart
/// final parameters = ConsoleGameParameters(appConfig, scenarioManager);
/// await parameters.initialize();
/// ```
class ConsoleGameParameters implements GameParameters {
  @override
  final AppConfig config;

  @override
  final ScenarioManager scenarioManager;

  @override
  GameScenario? currentScenario;

  ConsoleGameParameters(this.config, this.scenarioManager);

  /// 初始化参数系统（控制台模式已在构造函数中完成）
  @override
  Future<void> initialize() async {
    // 控制台模式不需要额外初始化
  }

  /// 保存配置（控制台模式不支持）
  @override
  Future<void> saveConfig(AppConfig newConfig) async {
    print('控制台模式不支持保存配置，请手动编辑 werewolf_config.yaml 文件');
  }

  /// 设置当前场景
  @override
  void setCurrentScenario(String scenarioId) {
    final scenario = scenarioManager.getScenario(scenarioId);
    if (scenario == null) {
      throw Exception('场景不存在: $scenarioId');
    }
    currentScenario = scenario;
  }

  /// 获取当前场景
  @override
  GameScenario? get scenario => currentScenario;

  /// 获取适合指定玩家数量的场景
  @override
  List<GameScenario> getAvailableScenarios(int playerCount) {
    return scenarioManager.getScenariosByPlayerCount(playerCount);
  }

  /// 为指定玩家获取 LLM 配置
  @override
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber) {
    return config.getPlayerLLMConfig(playerNumber);
  }
}
