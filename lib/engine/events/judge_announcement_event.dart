import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 法官公告事件 - 不可见
class JudgeAnnouncementEvent extends GameEvent {
  final String announcement;
  final int? dayNumber;
  final GamePhase? phase;

  JudgeAnnouncementEvent({
    required this.announcement,
    this.dayNumber,
    this.phase,
  }) : super(eventId: 'announcement_${DateTime.now().millisecondsSinceEpoch}');
}
