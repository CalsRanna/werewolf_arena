import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 狼人讨论事件 - 仅狼人可见
class WerewolfDiscussionEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfDiscussionEvent({
    required this.speaker,
    required this.message,
    this.dayNumber,
    this.phase,
  }) : super(
         id: 'speak_${DateTime.now().millisecondsSinceEpoch}',
         visibility: ['werewolf'],
       );

  @override
  String toString() {
    return 'WerewolfDiscussionEvent(id: $id)';
  }
}
