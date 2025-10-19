import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 守卫保护事件 - 仅守卫可见
class GuardProtectEvent extends GameEvent {
  GuardProtectEvent({required GamePlayer target})
    : super(
        id: 'protect_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['guard'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，守卫保护了${target?.name}';
  }

  @override
  String toString() {
    return 'GuardProtectEvent($id)';
  }
}
