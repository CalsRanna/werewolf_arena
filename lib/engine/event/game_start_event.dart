import 'package:werewolf_arena/engine/event/game_event.dart';

/// 游戏开始事件 - 公开可见
class GameStartEvent extends GameEvent {
  final int playerCount;

  GameStartEvent({required this.playerCount})
    : super(
        id: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
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
  String toNarrative() => '游戏开始';

  @override
  String toString() {
    return 'GameStartEvent($id)';
  }
}
