import '../engine/game_scenario.dart';
import 'scenarios_standard_12.dart';
import 'scenarios_simple_9.dart';

/// 场景管理器
/// 负责管理所有可用的游戏场景
class ScenarioManager {
  static final ScenarioManager _instance = ScenarioManager._internal();
  factory ScenarioManager() => _instance;
  ScenarioManager._internal();

  final Map<String, GameScenario> _scenarios = {};

  /// 初始化所有内置场景
  void initialize() {
    // 注册内置场景
    registerScenario(Standard12PlayersScenario());
    registerScenario(Simple9PlayersScenario());
  }

  /// 获取所有已注册的场景
  Map<String, GameScenario> get scenarios => Map.unmodifiable(_scenarios);

  /// 注册新场景
  void registerScenario(GameScenario scenario) {
    _scenarios[scenario.id] = scenario;
  }

  /// 根据ID获取场景
  GameScenario? getScenario(String id) {
    return _scenarios[id];
  }

  /// 根据玩家数量获取适合的场景
  List<GameScenario> getScenariosByPlayerCount(int playerCount) {
    return _scenarios.values
        .where((scenario) => scenario.playerCount == playerCount)
        .toList();
  }

  /// 获取所有可用的玩家数量
  List<int> getAvailablePlayerCounts() {
    return _scenarios.values
        .map((scenario) => scenario.playerCount)
        .toSet()
        .toList()
      ..sort();
  }

  /// 获取场景列表摘要
  List<Map<String, dynamic>> getScenarioSummaries() {
    return _scenarios.values.map((scenario) => scenario.getSummary()).toList();
  }

  /// 移除场景
  void removeScenario(String id) {
    _scenarios.remove(id);
  }

  /// 清空所有场景
  void clear() {
    _scenarios.clear();
  }
}
