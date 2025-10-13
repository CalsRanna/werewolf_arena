import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 阶段转换事件 - 公开可见
class PhaseChangeEvent extends GameEvent {
  final GamePhase oldPhase;
  final GamePhase newPhase;
  final int dayNumber;

  PhaseChangeEvent({
    required this.oldPhase,
    required this.newPhase,
    required this.dayNumber,
  }) : super(
         eventId: 'phase_change_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.phaseChange,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // 阶段转换由GameState处理
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'oldPhase': oldPhase.name,
      'newPhase': newPhase.name,
      'dayNumber': dayNumber,
    };
  }
}
