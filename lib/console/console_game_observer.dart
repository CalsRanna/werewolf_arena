import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/game_log_event.dart';
import 'package:werewolf_arena/engine/event/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/speech_order_announcement_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

/// 控制台游戏观察者
///
/// 实现 GameObserver 接口，将游戏事件转换为控制台输出。
/// 这是游戏引擎与控制台显示之间的桥梁。
class ConsoleGameObserver extends GameObserver {
  final ConsoleGameUI _console = ConsoleGameUI.instance;

  @override
  Future<void> onGameEvent(GameEvent event) async {
    if (event is GameLogEvent) {
      _console.printLog(event.toNarrative());
    } else if (event is JudgeAnnouncementEvent) {
      _console.printEvent('[法官]：${event.announcement}');
    } else if (event is ConspireEvent) {
      _console.printEvent('${event.speaker.formattedName}：${event.message}');
    } else if (event is DiscussEvent) {
      _console.printEvent('${event.speaker.formattedName}：${event.message}');
    } else if (event is VoteEvent) {
      _console.printEvent(
        '${event.voter.formattedName}投票给${event.candidate.formattedName}',
      );
    } else if (event is SpeechOrderAnnouncementEvent) {
      _console.printEvent('[法官]：${event.toNarrative()}');
    } else {
      _console.printEvent(event.toString());
    }
  }
}
