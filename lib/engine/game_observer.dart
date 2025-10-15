import 'package:werewolf_arena/engine/events/game_event.dart';

abstract class GameObserver {
  Future<void> onGameEvent(GameEvent event);
}
