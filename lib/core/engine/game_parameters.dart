import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/core/scenarios/scenario_registry.dart';
import 'package:werewolf_arena/services/config/config.dart';

/// 游戏参数接口
///
/// 定义了游戏引擎运行所需的所有配置参数，包括：
/// - 应用配置（LLM、日志等）
/// - 游戏场景配置
/// - 场景管理器
///
/// 实现类：
/// - FlutterGameParameters: Flutter GUI 应用的参数实现（使用 SharedPreferences）
/// - ConsoleGameParameters: 控制台应用的参数实现（使用文件系统）
abstract class GameParameters {
  /// 获取应用配置
  AppConfig get config;

  /// 获取场景管理器
  ScenarioManager get scenarioManager;

  /// 获取/设置当前场景
  GameScenario? get currentScenario;
  set currentScenario(GameScenario? value);

  /// 获取当前场景（便捷方法）
  GameScenario? get scenario;

  /// 初始化参数系统
  Future<void> initialize();

  /// 保存配置
  Future<void> saveConfig(AppConfig newConfig);

  /// 设置当前场景（通过场景ID）
  void setCurrentScenario(String scenarioId);

  /// 获取适合指定玩家数量的场景列表
  List<GameScenario> getAvailableScenarios(int playerCount);

  /// 为指定玩家获取 LLM 配置
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber);
}
