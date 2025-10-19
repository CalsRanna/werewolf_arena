import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 遗言事件 - 公开可见
class LastWordsEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;

  LastWordsEvent({required this.speaker, required this.message})
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
    return '第$dayNumber天${phase?.displayName}，${speaker.name}发表了遗言：$message';
  }

  @override
  String toString() {
    return 'LastWordsEvent($id)';
  }
}
