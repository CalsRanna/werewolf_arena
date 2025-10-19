import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 狼人击杀事件 - 仅狼人可见
class KillEvent extends GameEvent {
  KillEvent({required GamePlayer target})
    : super(
        id: 'kill_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['werewolf', 'witch'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，狼人击杀：${target?.name}';
  }

  @override
  String toString() {
    return 'KillEvent($id)';
  }
}
