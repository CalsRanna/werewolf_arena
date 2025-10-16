import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 女巫救人事件 - 仅女巫可见
class WitchHealEvent extends GameEvent {
  WitchHealEvent({required GamePlayer target})
    : super(
        id: 'heal_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['witch', 'werewolf'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，女巫救人：${target?.name}';
  }

  @override
  String toString() {
    return 'WitchHealEvent($id)';
  }
}
