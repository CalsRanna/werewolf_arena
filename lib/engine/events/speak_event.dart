import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 发言事件 - 所有人可见
class SpeakEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;
  final int? dayNumber;
  final GamePhase? phase;

  SpeakEvent({
    required this.speaker,
    required this.message,
    this.dayNumber,
    this.phase,
  }) : super(
         id: 'speak_${DateTime.now().millisecondsSinceEpoch}',
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
  String toString() {
    return 'SpeakEvent(id: $id)';
  }
}
