import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/events/game_log_event.dart';

import 'console_output.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

/// 控制台游戏观察者
///
/// 实现 GameObserver 接口，将游戏事件转换为控制台输出。
/// 这是游戏引擎与控制台显示之间的桥梁。
class ConsoleGameObserver extends GameObserver {
  final GameConsole _console = GameConsole.instance;

  @override
  Future<void> onGameEvent(GameEvent event) async {
    if (event is GameLogEvent) {
      _console.printLine(event.toString());
    } else {
      _console.printEvent(event.toString());
    }
  }
}
