import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 女巫救人事件 - 仅女巫可见
class HealEvent extends GameEvent {
  HealEvent({required GamePlayer target})
    : super(
        id: 'heal_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['witch', 'werewolf'],
      );

  @override
  String toNarrative() {
    return '女巫选择对${target?.name}使用解药';
  }

  @override
  String toString() {
    return 'WitchHealEvent($id)';
  }
}
