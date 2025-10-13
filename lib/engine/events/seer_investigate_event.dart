import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends GameEvent {
  final GamePlayer actor;
  final String investigationResult;
  final int? dayNumber;
  final GamePhase? phase;

  SeerInvestigateEvent({
    required this.actor,
    required GamePlayer target,
    required this.investigationResult,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'investigate_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.skillUsed,
         initiator: actor,
         target: target,
         visibility: EventVisibility.playerSpecific,
         visibleToPlayerNames: [actor.name],
       );

  @override
  void execute(GameState state) {
    // Investigation result is already stored in the event data
    // The seer will access this information through the event system
  }
}
