import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 玩家死亡事件 - 公开可见
class DeadEvent extends GameEvent {
  final GamePlayer victim;
  final DeathCause cause;
  final GamePlayer? killer;
  final int? dayNumber;
  final GamePhase? phase;

  DeadEvent({
    required this.victim,
    required this.cause,
    this.killer,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'death_${victim.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.playerDeath,
         initiator: victim,
         target: killer,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    victim.setAlive(false);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'victim': victim.name,
      'cause': cause.name,
      'killer': killer?.name,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}
