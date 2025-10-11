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

    // 分类技能结果
    final killResults = _getKillResults(results);
    final protectResults = _getProtectResults(results);
    final healResults = _getHealResults(results);
    final otherResults = _getOtherResults(results);

    // 处理保护vs击杀冲突
    await _resolveProtectionConflicts(killResults, protectResults, state);

    // 处理治疗vs击杀冲突
    await _resolveHealingConflicts(killResults, healResults, state);

    // 处理其他技能结果
    await _processOtherResults(otherResults, state);

    // 最终验证和清理
    await _finalizeResults(state);
  }

  /// 获取击杀类技能结果
  List<SkillResult> _getKillResults(List<SkillResult> results) {
    return results
        .where(
          (result) =>
              result.success && result.target != null && _isKillSkill(result),
        )
        .toList();
  }

  /// 获取保护类技能结果
  List<SkillResult> _getProtectResults(List<SkillResult> results) {
    return results
        .where(
          (result) =>
              result.success &&
              result.target != null &&
              _isProtectSkill(result),
        )
        .toList();
  }

  /// 获取治疗类技能结果
  List<SkillResult> _getHealResults(List<SkillResult> results) {
    return results
        .where(
          (result) =>
              result.success && result.target != null && _isHealSkill(result),
        )
        .toList();
  }

  /// 获取其他技能结果
  List<SkillResult> _getOtherResults(List<SkillResult> results) {
    return results
        .where(
          (result) =>
              !_isKillSkill(result) &&
              !_isProtectSkill(result) &&
              !_isHealSkill(result),
        )
        .toList();
  }

  /// 解决保护vs击杀冲突
  Future<void> _resolveProtectionConflicts(
    List<SkillResult> killResults,
    List<SkillResult> protectResults,
    GameState state,
  ) async {
    for (final killResult in killResults) {
      final target = killResult.target;
      if (target == null) continue;

      // 检查是否有保护效果
      final isProtected = protectResults.any(
        (protectResult) => protectResult.target == target,
      );

      if (isProtected) {
        // 击杀被保护抵消，撤销击杀效果
        await _cancelKillEffect(killResult, state);
      }
    }
  }

  /// 解决治疗vs击杀冲突
  Future<void> _resolveHealingConflicts(
    List<SkillResult> killResults,
    List<SkillResult> healResults,
    GameState state,
  ) async {
    for (final killResult in killResults) {
      final target = killResult.target;
      if (target == null) continue;

      // 检查是否有治疗效果
      final isHealed = healResults.any(
        (healResult) => healResult.target == target,
      );

      if (isHealed) {
        // 击杀被治疗抵消，撤销击杀效果
        await _cancelKillEffect(killResult, state);
      }
    }
  }

  /// 处理其他技能结果
  Future<void> _processOtherResults(
    List<SkillResult> otherResults,
    GameState state,
  ) async {
    for (final result in otherResults) {
      await _applySkillEffect(result, state);
    }
  }

  /// 最终验证和清理
  Future<void> _finalizeResults(GameState state) async {
    // 进行最终的状态检查和清理
    // 例如：确保游戏状态的一致性
  }

  /// 撤销击杀效果
  Future<void> _cancelKillEffect(
    SkillResult killResult,
    GameState state,
  ) async {
    final target = killResult.target;
    if (target == null) return;

    // 这里需要与GameState的实际API对接
    // 暂时使用注释说明逻辑

    // 如果目标已经被标记为死亡，需要撤销死亡状态
    // state.cancelPlayerDeath(target);

    // 添加保护成功的事件
    // state.addEvent(ProtectionSuccessEvent(...));
  }

  /// 应用技能效果
  Future<void> _applySkillEffect(SkillResult result, GameState state) async {
    // 根据技能类型应用相应的效果
    // 这里需要根据具体的技能系统设计来实现

    // 例如：
    // - 查验技能：添加查验结果事件
    // - 发言技能：添加发言事件
    // - 投票技能：记录投票结果
  }

  /// 判断是否为击杀类技能
  bool _isKillSkill(SkillResult result) {
    final skillId = result.metadata['skillId'] as String?;
    return skillId != null &&
        (skillId.contains('kill') ||
            skillId.contains('poison') ||
            skillId.contains('shoot'));
  }

  /// 判断是否为保护类技能
  bool _isProtectSkill(SkillResult result) {
    final skillId = result.metadata['skillId'] as String?;
    return skillId != null &&
        (skillId.contains('protect') || skillId.contains('guard'));
  }

  /// 判断是否为治疗类技能
  bool _isHealSkill(SkillResult result) {
    final skillId = result.metadata['skillId'] as String?;
    return skillId != null &&
        (skillId.contains('heal') || skillId.contains('antidote'));
  }
}
