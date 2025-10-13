import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 系统错误事件 - 公开可见
class SystemErrorEvent extends GameEvent {
  final String errorMessage;
  final dynamic error;

  SystemErrorEvent({required this.errorMessage, required this.error})
    : super(
        eventId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        type: GameEventType.playerAction,
        visibility: EventVisibility.public,
      );

  @override
  void execute(GameState state) {
    // Error events don't modify game state
  }
}
