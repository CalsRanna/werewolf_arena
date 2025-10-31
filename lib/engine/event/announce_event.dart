import 'package:werewolf_arena/engine/event/game_event.dart';

/// 法官公告事件 - 不可见
class AnnounceEvent extends GameEvent {
  final String message;

  AnnounceEvent(this.message, {required super.day});

  @override
  String toNarrative() {
    return '第$day天，法官宣布了$message';
  }
}
