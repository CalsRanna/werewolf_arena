import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 守卫保护事件 - 仅守卫可见
class ProtectEvent extends GameEvent {
  final GamePlayer target;

  ProtectEvent({required super.day, required this.target})
    : super(visibility: ['guard']);

  @override
  String toNarrative() {
    return '第$day天，守卫选择保护${target.name}';
  }
}
