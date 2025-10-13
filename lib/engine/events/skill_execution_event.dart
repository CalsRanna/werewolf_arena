import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 通用技能执行事件 - 可配置可见性
class SkillExecutionEvent extends GameEvent {
  final String skillId;
  final String skillName;
  final GamePlayer caster;
  @override
  final GamePlayer? target;
  final Map<String, dynamic> skillData;
  final int? dayNumber;
  final GamePhase? phase;

  SkillExecutionEvent({
    required this.skillId,
    required this.skillName,
    required this.caster,
    this.target,
    this.skillData = const {},
    this.dayNumber,
    this.phase,
    super.visibility = EventVisibility.playerSpecific,
    List<String>? visibleToPlayerNames,
  }) : super(
         eventId:
             'skill_${skillId}_${caster.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.skillUsed,
         initiator: caster,
         target: target,
         visibleToPlayerNames: visibleToPlayerNames ?? [caster.name],
       );

  @override
  void execute(GameState state) {
    // 技能执行的具体逻辑在技能类中处理，这里只记录事件
    // 可以根据skillData中的信息执行相应的状态变更

    // 更新技能使用次数
    state.incrementSkillUsage(skillId);

    // 根据技能类型设置相应的技能效果
    if (skillData.isNotEmpty) {
      final effectKey = '${skillId}_${caster.name}';
      state.setSkillEffect(effectKey, skillData);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'skillId': skillId,
      'skillName': skillName,
      'caster': caster.name,
      'target': target?.name,
      'skillData': skillData,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}
