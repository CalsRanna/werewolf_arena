import 'package:werewolf_arena/engine/events/game_event.dart';

/// 游戏结束事件 - 公开可见
class GameEndEvent extends GameEvent {
  final String winner;
  final int totalDays;
  final int finalPlayerCount;
  final DateTime gameStartTime;

  GameEndEvent({
    required this.winner,
    required this.totalDays,
    required this.finalPlayerCount,
    required this.gameStartTime,
  }) : super(
         id: 'game_end_${DateTime.now().millisecondsSinceEpoch}',
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
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，游戏结束，$winner获胜';
  }

  @override
  String toString() {
    return 'GameEndEvent($id)';
  }
}
