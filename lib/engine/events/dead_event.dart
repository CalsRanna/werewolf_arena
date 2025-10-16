import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 玩家死亡事件 - 公开可见
class DeadEvent extends GameEvent {
  final GamePlayer victim;
  final DeathCause cause;
  final int? dayNumber;
  final GamePhase? phase;

  DeadEvent({
    required this.victim,
    required this.cause,
    this.dayNumber,
    this.phase,
  }) : super(
         id: 'death_${DateTime.now().millisecondsSinceEpoch}',
         visibility: [
           'villager',
           'werewolf',
           'seer',
           'witch',
           'hunter',
           'guardian',
         ],
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'victim': victim.name,
      'cause': cause.name,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }

  @override
  String toString() {
    return 'DeadEvent(id: $id)';
  }
}
