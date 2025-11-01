import 'package:werewolf_arena/engine/event/game_event.dart';

/// 系统事件，所有玩家不可见
class SystemEvent extends GameEvent {
  final String message;

  SystemEvent(this.message);

  @override
  String toNarrative() => message;
}
