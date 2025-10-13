import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/events/dead_event.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 夜晚结果公告事件 - 公开可见
class NightResultEvent extends GameEvent {
  final List<DeadEvent> deathEvents;
  final bool isPeacefulNight;
  final int dayNumber;

  NightResultEvent({
    required this.deathEvents,
    required this.isPeacefulNight,
    required this.dayNumber,
  }) : super(
         eventId: 'night_result_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.dayBreak,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // Night result announcement is handled by GameEngine
    // This event just provides information to players
  }
}
