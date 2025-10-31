import 'package:werewolf_arena/engine/event/game_event.dart';

/// 法官公告事件 - 不可见
class AnnounceEvent extends GameEvent {
  final String announcement;

  AnnounceEvent(this.announcement, {required super.dayNumber});

  @override
  String toNarrative() {
    return '第$dayNumber天，法官宣布了$announcement';
  }
}
