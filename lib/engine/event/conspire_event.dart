import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 狼人讨论事件 - 仅狼人可见
class ConspireEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;

  ConspireEvent({required this.speaker, required this.message})
    : super(
        id: 'conspire_${DateTime.now().millisecondsSinceEpoch}',
        visibility: ['werewolf'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天晚上，狼人讨论：$message';
  }

  @override
  String toString() {
    return 'ConspireEvent($id)';
  }
}
