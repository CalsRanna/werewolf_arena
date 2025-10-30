import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 游戏场景抽象类
/// 定义不同游戏板子的基础接口和行为
abstract class GameScenario {
  /// 场景唯一标识
  String get id;

  /// 场景名称
  String get name;

  /// 场景描述
  String get description;

  /// 游戏规则说明（供玩家查看）
  /// 用于向不熟悉该板子的用户解释规则
  String get rule;

  List<GameRole> get roles;

  /// 检查胜利条件
  /// 返回获胜方名称，null 表示游戏继续
  String? getWinner(GameState state);
}
