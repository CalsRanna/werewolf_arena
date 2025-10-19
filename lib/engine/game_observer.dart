import 'package:werewolf_arena/engine/event/game_event.dart';

abstract class GameObserver {
  Future<void> onGameEvent(GameEvent event);
}
