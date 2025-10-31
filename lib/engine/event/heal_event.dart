import 'package:werewolf_arena/engine/event/game_event.dart';

/// 女巫救人事件 - 仅女巫可见
class HealEvent extends GameEvent {
  HealEvent({required super.target, required super.day})
    : super(visibility: ['witch']);

  @override
  String toNarrative() {
    return '第$day天，女巫选择对${target?.name}使用解药';
  }
}
