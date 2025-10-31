import 'package:werewolf_arena/engine/event/game_event.dart';

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
    required super.day,
  }) : super(
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
    return '第$day天，游戏结束，$winner获胜';
  }
}
