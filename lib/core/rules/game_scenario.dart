import '../entities/player/role.dart';
import '../state/game_state.dart';

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

  /// 场景难度
  String get difficulty;

  /// 场景标签
  List<String> get tags;

  /// 角色分布配置
  Map<String, int> get roleDistribution;

  /// 游戏规则描述（用于生成提示词）
  String get rulesDescription;

  /// 夜晚动作优先级顺序
  List<String> get nightActionPriority;

  /// 初始化场景
  /// 在游戏开始前调用，用于设置场景特定的初始状态
  void initialize(GameState gameState);

  /// 检查游戏是否结束
  /// 返回游戏结束状态和获胜阵营
  GameEndResult checkGameEnd(GameState gameState);

  /// 获取下一个应该执行动作的角色类型
  /// 返回null表示没有更多动作需要执行
  String? getNextActionRole(GameState gameState, List<String> completedActions);

  /// 处理特殊场景规则
  /// 在每个阶段结束时调用
  void handlePhaseEnd(GameState gameState);

  /// 验证角色分布是否有效
  bool isValidRoleDistribution() {
    final totalRoles = roleDistribution.values.fold(0, (sum, count) => sum + count);
    return totalRoles == playerCount;
  }

  /// 获取展开的角色列表（根据数量）
  List<String> getExpandedRoles() {
    final expandedRoles = <String>[];
    for (final entry in roleDistribution.entries) {
      for (int i = 0; i < entry.value; i++) {
        expandedRoles.add(entry.key);
      }
    }
    return expandedRoles;
  }

  /// 创建角色实例
  Role createRole(String roleId) {
    switch (roleId) {
      case 'werewolf':
        return WerewolfRole();
      case 'villager':
        return VillagerRole();
      case 'seer':
        return SeerRole();
      case 'witch':
        return WitchRole();
      case 'hunter':
        return HunterRole();
      case 'guard':
        return GuardRole();
      default:
        throw Exception('未知的角色类型: $roleId');
    }
  }

  /// 场景摘要信息
  Map<String, dynamic> getSummary() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'playerCount': playerCount,
      'difficulty': difficulty,
      'tags': tags,
      'roleDistribution': roleDistribution,
    };
  }

  /// 转换为JSON（用于序列化）
  Map<String, dynamic> toJson() {
    return getSummary();
  }
}

/// 游戏结束结果
class GameEndResult {
  final bool isEnded;
  final String? winner;
  final String? reason;

  GameEndResult({
    required this.isEnded,
    this.winner,
    this.reason,
  });

  factory GameEndResult.continueGame() {
    return GameEndResult(isEnded: false);
  }

  factory GameEndResult.ended({
    required String winner,
    String? reason,
  }) {
    return GameEndResult(
      isEnded: true,
      winner: winner,
      reason: reason,
    );
  }
}