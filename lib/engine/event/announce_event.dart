import 'package:werewolf_arena/engine/event/game_event.dart';

/// 法官公告事件 - 不可见
class AnnounceEvent extends GameEvent {
  final String announcement;

  AnnounceEvent(this.announcement)
    : super(id: 'announcement_${DateTime.now().millisecondsSinceEpoch}');

  @override
  String toNarrative() {
    return '第$dayNumber天，法官宣布了$announcement';
  }

  @override
  String toString() {
    return 'AnnounceEvent($id)';
  }
}
