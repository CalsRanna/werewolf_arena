import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

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
         eventId: 'game_end_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.gameEnd,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // Game end logic is handled by GameState
  }
}
