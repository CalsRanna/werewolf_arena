import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 守卫保护事件 - 仅守卫可见
class ProtectEvent extends GameEvent {
  ProtectEvent({required GamePlayer target})
    : super(
        id: 'protect_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['guard'],
      );

  @override
  String toNarrative() {
    return '守卫选择保护${target?.name}';
  }

  @override
  String toString() {
    return 'ProtectEvent($id)';
  }
}
