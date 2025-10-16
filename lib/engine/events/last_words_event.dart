import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 遗言事件 - 公开可见
class LastWordsEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;
  final int? dayNumber;
  final GamePhase? phase;

  LastWordsEvent({
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
}
