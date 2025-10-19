import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 发言事件 - 所有人可见
class SpeakEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;

  SpeakEvent({required this.speaker, required this.message})
    : super(
        id: 'speak_${DateTime.now().millisecondsSinceEpoch}',
        visibility: [
          'villager',
          'werewolf',
          'seer',
          'witch',
          'hunter',
          'guard',
        ],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，${speaker.name}发表了发言：$message';
  }

  @override
  String toString() {
    return 'SpeakEvent($id)';
  }
}
