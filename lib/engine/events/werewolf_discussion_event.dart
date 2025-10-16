import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 狼人讨论事件 - 仅狼人可见
class WerewolfDiscussionEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;

  WerewolfDiscussionEvent({required this.speaker, required this.message})
    : super(
        id: 'speak_${DateTime.now().millisecondsSinceEpoch}',
        visibility: ['werewolf'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，狼人讨论：$message';
  }

  @override
  String toString() {
    return 'WerewolfDiscussionEvent($id)';
  }
}
