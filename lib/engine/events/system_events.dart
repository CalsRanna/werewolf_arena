import 'package:werewolf_arena/engine/events/base/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/state/game_state.dart';

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

/// 游戏结束事件 - 公开可见
class GameEndEvent extends GameEvent {
  final String winner;
  final int totalDays;
  final int finalPlayerCount;
  final DateTime gameStartTime;

  GameEndEvent({
    required this.winner,
    required this.totalDays,
    required this.finalPlayerCount,
    required this.gameStartTime,
  }) : super(
         eventId: 'game_end_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.gameEnd,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // Game end logic is handled by GameState
  }
}

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

/// 法官公告事件 - 公开可见
///
/// 用于通知所有玩家公共信息,如游戏进程提示等
class JudgeAnnouncementEvent extends GameEvent {
  final String announcement;
  final int? dayNumber;
  final GamePhase? phase;

  JudgeAnnouncementEvent({
    required this.announcement,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId: 'announcement_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.phaseChange,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // 公告事件不需要执行具体逻辑，只是传递信息
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'announcement': announcement,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }

  @override
  String toString() {
    return 'JudgeAnnouncement: $announcement';
  }
}
