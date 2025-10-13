import 'package:werewolf_arena/engine/domain/entities/game_player.dart';

/// 技能执行结果
///
/// 简化的技能结果设计，只包含核心信息，避免过度设计
class SkillResult {
  /// 施放技能的玩家
  final GamePlayer caster;

  /// 技能的目标玩家（可选）
  final GamePlayer? target;

  final String? message;

  final String reasoning;

  const SkillResult({
    required this.caster,
    this.target,
    this.message,
    required this.reasoning,
  });
}
