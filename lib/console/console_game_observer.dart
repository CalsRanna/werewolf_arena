import 'package:werewolf_arena/console/console_output.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/events/game_log_event.dart';
import 'package:werewolf_arena/engine/events/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/events/speak_event.dart';
import 'package:werewolf_arena/engine/events/speech_order_announcement_event.dart';
import 'package:werewolf_arena/engine/events/vote_event.dart';
import 'package:werewolf_arena/engine/events/werewolf_discussion_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

/// 控制台游戏观察者
///
/// 实现 GameObserver 接口，将游戏事件转换为控制台输出。
/// 这是游戏引擎与控制台显示之间的桥梁。
class ConsoleGameObserver extends GameObserver {
  final ConsoleGameOutput _console = ConsoleGameOutput.instance;

  @override
  Future<void> onGameEvent(GameEvent event) async {
    if (event is GameLogEvent) {
      _console.printLine(event.toNarrative());
    } else if (event is JudgeAnnouncementEvent) {
      _console.printEvent('[法官]：${event.announcement}');
    } else if (event is WerewolfDiscussionEvent) {
      _console.printEvent('${event.speaker.formattedName}：${event.message}');
    } else if (event is SpeakEvent) {
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
