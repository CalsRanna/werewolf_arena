import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

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
    return 'JudgeAnnouncementEvent($announcement)';
  }
}
