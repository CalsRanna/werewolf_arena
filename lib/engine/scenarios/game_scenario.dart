import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/victory_result.dart';
import 'package:werewolf_arena/engine/state/game_state.dart';

/// 游戏场景抽象类
/// 定义不同游戏板子的基础接口和行为
abstract class GameScenario {
  /// 场景唯一标识
  String get id;

  /// 场景名称
  String get name;

  /// 场景描述
  String get description;

  /// 玩家数量
  int get playerCount;

  /// 游戏规则说明（供玩家查看）
  /// 用于向不熟悉该板子的用户解释规则
  String get rule;

  /// 角色分布配置
  Map<RoleType, int> get roleDistribution;

  /// 获取展开的角色列表（根据数量）
  List<RoleType> getExpandedGameRoles();

  /// 创建角色实例
  GameRole createGameRole(RoleType roleType);

  /// 检查胜利条件
  VictoryResult checkVictoryCondition(GameState state);

  /// 验证角色分布是否有效
  bool isValidGameRoleDistribution() {
    final totalGameRoles = roleDistribution.values.fold(
      0,
      (sum, count) => sum + count,
    );
    return totalGameRoles == playerCount;
  }
}
