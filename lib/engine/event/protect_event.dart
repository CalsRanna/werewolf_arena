import 'package:werewolf_arena/engine/event/game_event.dart';

/// 守卫保护事件 - 仅守卫可见
class ProtectEvent extends GameEvent {
  ProtectEvent({required super.target, required super.dayNumber})
    : super(visibility: ['guard']);

  @override
  String toNarrative() {
    return '第$dayNumber天，守卫选择保护${target?.name}';
  }
}
