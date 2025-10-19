import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/engine/event/dead_event.dart';
import 'package:werewolf_arena/engine/event/exile_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/heal_event.dart';
import 'package:werewolf_arena/engine/event/investigate_event.dart';
import 'package:werewolf_arena/engine/event/kill_event.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';
import 'package:werewolf_arena/engine/event/announce_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/order_event.dart';
import 'package:werewolf_arena/engine/event/poison_event.dart';
import 'package:werewolf_arena/engine/event/protect_event.dart';
import 'package:werewolf_arena/engine/event/shoot_event.dart';
import 'package:werewolf_arena/engine/event/testament_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

/// 控制台游戏观察者
///
/// 实现 GameObserver 接口，将游戏事件转换为控制台输出。
/// 这是游戏引擎与控制台显示之间的桥梁。
class ConsoleGameObserver extends GameObserver {
  final ConsoleGameUI ui;

  ConsoleGameObserver({required this.ui});

  @override
  Future<void> onGameEvent(GameEvent event) async {
    if (event is LogEvent) {
      ui.printLog(event.toNarrative());
    } else if (event is AnnounceEvent) {
      ui.printEvent('[法官]：${event.announcement}');
    } else if (event is OrderEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is ProtectEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is KillEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is InvestigateEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is ExileEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is HealEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is PoisonEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is ShootEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
    } else if (event is ConspireEvent) {
      ui.printEvent('${event.speaker.formattedName}：${event.message}');
    } else if (event is DiscussEvent) {
      ui.printEvent('${event.speaker.formattedName}：${event.message}');
    } else if (event is VoteEvent) {
      ui.printEvent(
        '${event.voter.formattedName}投票给${event.candidate.formattedName}',
      );
    } else if (event is TestamentEvent) {
      ui.printEvent('${event.speaker.formattedName}：${event.message}');
    } else if (event is DeadEvent) {
      // do nothing
    } else {
      ui.printEvent(event.toString());
    }
  }
}
