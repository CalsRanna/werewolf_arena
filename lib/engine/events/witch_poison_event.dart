import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 女巫毒杀事件 - 仅女巫可见
class WitchPoisonEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchPoisonEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'poison_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.skillUsed,
         initiator: actor,
         target: target,
         visibility: EventVisibility.playerSpecific,
         visibleToPlayerNames: [actor.name],
       );

  @override
  void execute(GameState state) {
    // state.setTonightPoisoned(target!);
  }
}
