import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 猎人开枪事件 - 公开可见
class ShootEvent extends GameEvent {
  final GamePlayer target;

  ShootEvent({required super.day, required this.target})
    : super(visibility: ['hunter']);

  @override
  String toNarrative() {
    return '第$day天，猎人选择带走${target.name}';
  }
}
