import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 遗言事件 - 公开可见
class TestamentEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;

  TestamentEvent({required this.speaker, required this.message})
    : super(
        id: 'testament_${DateTime.now().millisecondsSinceEpoch}',
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
    return '第$dayNumber天，${speaker.name}发表遗言：$message';
  }

  @override
  String toString() {
    return 'TestamentEvent($id)';
  }
}
