import 'package:werewolf_arena/engine/events/game_event.dart';

/// 法官公告事件 - 不可见
class JudgeAnnouncementEvent extends GameEvent {
  final String announcement;

  JudgeAnnouncementEvent({required this.announcement})
    : super(id: 'announcement_${DateTime.now().millisecondsSinceEpoch}');

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，法官宣布了$announcement';
  }

  @override
  String toString() {
    return 'JudgeAnnouncementEvent($id)';
  }
}
