import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/engine/event/dead_event.dart';
import 'package:werewolf_arena/engine/event/exile_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/heal_event.dart';
import 'package:werewolf_arena/engine/event/investigate_event.dart';
import 'package:werewolf_arena/engine/event/kill_event.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';
import 'package:werewolf_arena/engine/event/system_event.dart';
import 'package:werewolf_arena/engine/event/peaceful_night_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/order_event.dart';
import 'package:werewolf_arena/engine/event/poison_event.dart';
import 'package:werewolf_arena/engine/event/protect_event.dart';
import 'package:werewolf_arena/engine/event/shoot_event.dart';
import 'package:werewolf_arena/engine/event/testament_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 控制台游戏观察者
///
/// 实现 GameObserver 接口，将游戏事件转换为控制台输出。
/// 这是游戏引擎与控制台显示之间的桥梁。
class ConsoleGameObserver extends GameObserver {
  final ConsoleGameUI ui;
  final bool showLog;
  final bool showRole;
  final GamePlayer? humanPlayer;

  ConsoleGameObserver({
    required this.ui,
    this.showLog = false,
    this.showRole = false,
    this.humanPlayer,
  });

  @override
  Future<void> onGameEvent(GameEvent event) async {
    if (event is SystemEvent) ui.printEvent('[法官]：${event.message}');
    // 如果有人类玩家且不是上帝视角，检查事件可见性
    if (humanPlayer != null && !showRole) {
      if (!event.isVisibleTo(humanPlayer!)) {
        // 事件对该玩家不可见，跳过显示
        return;
      }
    }

    if (event is LogEvent) {
      if (!showLog) return;
      ui.printLog(event.toNarrative());
    } else if (event is PeacefulNightEvent) {
      ui.printEvent('[法官]：${event.toNarrative()}');
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
      var name = event.source.formattedName;
      if (!showRole) name = '[${event.source.name}]';
      ui.printEvent('$name：${event.message}');
    } else if (event is DiscussEvent) {
      var name = event.source.formattedName;
      if (!showRole) name = '[${event.source.name}]';
      ui.printEvent('$name：${event.message}');
    } else if (event is VoteEvent) {
      var voterName = event.voter.formattedName;
      if (!showRole) voterName = '[${event.voter.name}]';
      var candidateName = event.candidate.formattedName;
      if (!showRole) candidateName = '[${event.candidate.name}]';
      ui.printEvent('$voterName投票给$candidateName');
    } else if (event is TestamentEvent) {
      var name = event.source.formattedName;
      if (!showRole) name = '[${event.source.name}]';
      ui.printEvent('$name：${event.message}');
    } else if (event is DeadEvent) {
      // do nothing
    } else {
      ui.printEvent(event.toString());
    }
  }
}
