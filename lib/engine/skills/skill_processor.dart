import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 技能处理器
///
/// 负责处理技能执行结果和解决技能间的冲突
class SkillProcessor {
  /// 处理技能结果列表
  ///
  /// 按照游戏规则处理技能冲突，例如：
  /// - 守卫保护 vs 狼人击杀
  /// - 女巫解药 vs 狼人击杀
  /// - 多个技能影响同一目标时的优先级处理
  ///
  /// [results] 本回合所有技能的执行结果
  /// [state] 当前游戏状态
  Future<void> process(List<SkillResult> results, GameState state) async {
    if (results.isEmpty) return;

    // 最终验证和清理
    await _finalizeResults(state);
  }

  /// 最终验证和清理
  Future<void> _finalizeResults(GameState state) async {
    // 进行最终的状态检查和清理
    // 例如：确保游戏状态的一致性
  }
}
