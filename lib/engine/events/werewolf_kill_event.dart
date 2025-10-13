import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfKillEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId: 'kill_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.skillUsed,
         initiator: actor,
         target: target,
         visibility: EventVisibility.allWerewolves,
       );

  @override
  void execute(GameState state) {
    // Mark target for death (will be resolved at end of night)
    // state.setTonightVictim(target!);
  }
}
