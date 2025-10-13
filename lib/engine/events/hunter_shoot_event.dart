import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/dead_event.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 猎人开枪事件 - 公开可见
class HunterShootEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  HunterShootEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'hunter_shoot_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.skillUsed,
         initiator: actor,
         target: target,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // Create death event for the target
    final deathEvent = DeadEvent(
      victim: target!,
      cause: DeathCause.hunterShot,
      killer: actor,
      dayNumber: dayNumber,
      phase: phase,
    );
    deathEvent.execute(state);
    // state.addEvent(deathEvent);
  }
}
