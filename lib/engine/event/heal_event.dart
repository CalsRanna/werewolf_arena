import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 女巫救人事件 - 仅女巫可见
class HealEvent extends GameEvent {
  final GamePlayer target;

  HealEvent({required super.day, required this.target})
    : super(visibility: ['witch']);

  @override
  String toNarrative() {
    return '第$day天，女巫选择对${target.name}使用解药';
  }
}
