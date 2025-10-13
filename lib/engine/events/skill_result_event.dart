import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 技能结果事件 - 用于公布技能执行的结果
class SkillResultEvent extends GameEvent {
  final String skillId;
  final GamePlayer caster;
  final bool success;
  final String? resultMessage;
  final Map<String, dynamic> resultData;

  SkillResultEvent({
    required this.skillId,
    required this.caster,
    required this.success,
    this.resultMessage,
    this.resultData = const {},
    super.visibility = EventVisibility.public,
  }) : super(
         eventId:
             'skill_result_${skillId}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.skillResult,
         initiator: caster,
       );

  @override
  void execute(GameState state) {
    // 技能结果事件主要用于信息传递，不直接修改游戏状态
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'skillId': skillId,
      'caster': caster.name,
      'success': success,
      'resultMessage': resultMessage,
      'resultData': resultData,
    };
  }
}
