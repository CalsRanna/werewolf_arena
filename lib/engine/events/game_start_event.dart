import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 游戏开始事件 - 公开可见
class GameStartEvent extends GameEvent {
  final int playerCount;
  final Map<String, int> roleDistribution;

  GameStartEvent({required this.playerCount, required this.roleDistribution})
    : super(
        eventId: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
        type: GameEventType.gameStart,
        visibility: EventVisibility.public,
      );

  @override
  void execute(GameState state) {
    // Game start logic is handled by GameState
  }
}
