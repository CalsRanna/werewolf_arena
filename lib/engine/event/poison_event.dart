import 'package:werewolf_arena/engine/event/game_event.dart';

/// 女巫毒杀事件 - 仅女巫可见
class PoisonEvent extends GameEvent {
  PoisonEvent({required super.target, required super.day})
    : super(visibility: ['witch']);

  @override
  String toNarrative() {
    return '第$day天，女巫选择对${target?.name}使用毒药';
  }
}
