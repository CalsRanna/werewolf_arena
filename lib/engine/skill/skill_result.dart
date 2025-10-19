/// 技能执行结果
///
/// 简化的技能结果设计，只包含核心信息，避免过度设计
class SkillResult {
  /// 施放技能的玩家
  final String caster;

  /// 技能的目标玩家（可选）
  final String? target;

  final String? message;

  final String? reasoning;

  const SkillResult({
    required this.caster,
    this.target,
    this.message,
    this.reasoning,
  });

  factory SkillResult.fromJson(Map<String, dynamic> json) {
    return SkillResult(
      caster: json['caster'],
      target: json['target'],
      message: json['message'],
      reasoning: json['reasoning'],
    );
  }
}
