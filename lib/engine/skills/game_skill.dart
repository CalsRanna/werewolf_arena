import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 游戏技能抽象类
///
/// 统一所有游戏行为为技能系统，包括夜晚行动、白天发言、投票等。
/// 每个技能都有自己的提示词、优先级和执行逻辑。
abstract class GameSkill {
  /// 技能唯一标识
  String get skillId;

  /// 技能名称
  String get name;

  /// 技能描述
  String get description;

  /// 技能优先级
  ///
  /// 用于决定技能执行顺序，数值越高优先级越高。
  /// 例如：狼人击杀(100) > 守卫保护(90) > 预言家查验(80)
  int get priority;

  /// 技能提示词
  ///
  /// 为AI玩家提供该技能的具体行动指导，包括：
  /// - 技能的使用时机和条件
  /// - 需要考虑的策略因素
  /// - 预期的决策格式
  String get prompt;

  /// 判断是否可以施放技能
  ///
  /// [player] 要施放技能的玩家
  /// [state] 当前游戏状态
  ///
  /// 返回true表示可以施放，false表示不能施放
  bool canCast(GamePlayer player, GameState state);

  /// 施放技能
  ///
  /// [player] 施放技能的玩家
  /// [state] 当前游戏状态
  /// [aiResponse] AI玩家的响应数据（可选），包含AI生成的决策信息
  ///
  /// 返回技能执行结果
  Future<SkillResult?> cast(
    GamePlayer player,
    GameState state, {
    Map<String, dynamic>? aiResponse,
  });
}
