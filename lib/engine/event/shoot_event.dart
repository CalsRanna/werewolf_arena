import 'package:werewolf_arena/engine/event/game_event.dart';

/// 猎人开枪事件 - 公开可见
class ShootEvent extends GameEvent {
  ShootEvent({required super.target, required super.day})
    : super(visibility: ['hunter']);

  @override
  String toNarrative() {
    return '第$day天，猎人选择击杀${target?.name}';
  }
}
