// ignore_for_file: avoid_print

import 'package:werewolf_arena/engine/events/game_log_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

class ConsoleGameLogObserver extends GameObserverAdapter {
  @override
  void onGameLog(GameLogEvent logEvent) {
    print(
      '[${logEvent.timestamp}][${logEvent.level.name}] ${logEvent.message}',
    );
  }
}
