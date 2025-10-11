/// 技能执行结果
/// 
/// 简化的技能结果设计，只包含核心信息，避免过度设计
class SkillResult {
  /// 技能是否执行成功
  final bool success;
  
  /// 施放技能的玩家
  final dynamic caster;
  
  /// 技能的目标玩家（可选）
  final dynamic target;
  
  /// 附加信息（可选）
  final Map<String, dynamic> metadata;

  const SkillResult({
    required this.success,
    required this.caster,
    this.target,
    this.metadata = const {},
  });

  /// 创建成功的技能结果
  factory SkillResult.success({
    required dynamic caster,
    dynamic target,
    Map<String, dynamic> metadata = const {},
  }) {
    return SkillResult(
      success: true,
      caster: caster,
      target: target,
      metadata: metadata,
    );
  }

  /// 创建失败的技能结果
  factory SkillResult.failure({
    required dynamic caster,
    dynamic target,
    Map<String, dynamic> metadata = const {},
  }) {
    return SkillResult(
      success: false,
      caster: caster,
      target: target,
      metadata: metadata,
    );
  }

  /// 创建无目标的技能结果
  factory SkillResult.noTarget({
    required dynamic caster,
    bool success = true,
    Map<String, dynamic> metadata = const {},
  }) {
    return SkillResult(
      success: success,
      caster: caster,
      target: null,
      metadata: metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillResult &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          caster == other.caster &&
          target == other.target;

  @override
  int get hashCode => success.hashCode ^ caster.hashCode ^ target.hashCode;

  @override
  String toString() {
    return 'SkillResult{success: $success, caster: $caster, target: $target, metadata: $metadata}';
  }
}