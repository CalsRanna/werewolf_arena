import 'package:werewolf_arena/engine/event/game_event.dart';

/// 系统公告事件 - 公开可见
class SystemEvent extends GameEvent {
  final String message;

  SystemEvent(this.message, {required super.day})
    : super(visibility: const ['public']);

  @override
  String toNarrative() {
    return '第$day天，法官宣布了$message';
  }
}
