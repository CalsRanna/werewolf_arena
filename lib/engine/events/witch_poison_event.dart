import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 女巫毒杀事件 - 仅女巫可见
class WitchPoisonEvent extends GameEvent {
  WitchPoisonEvent({required GamePlayer target})
    : super(
        id: 'poison_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['witch'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，女巫毒杀：${target?.name}';
  }

  @override
  String toString() {
    return 'WitchPoisonEvent($id)';
  }
}
