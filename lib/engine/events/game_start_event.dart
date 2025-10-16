import 'package:werewolf_arena/engine/events/game_event.dart';

/// 游戏开始事件 - 公开可见
class GameStartEvent extends GameEvent {
  final int playerCount;
  final Map<String, int> roleDistribution;

  GameStartEvent({required this.playerCount, required this.roleDistribution})
    : super(
        id: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
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
