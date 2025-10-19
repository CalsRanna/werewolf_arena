import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 玩家死亡事件 - 公开可见
class DeadEvent extends GameEvent {
  final GamePlayer victim;

  DeadEvent({required this.victim})
    : super(
        id: 'death_${DateTime.now().millisecondsSinceEpoch}',
        visibility: [
          'villager',
          'werewolf',
          'seer',
          'witch',
          'hunter',
          'guard',
        ],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，玩家${victim.name}死亡';
  }

  @override
  String toString() {
    return 'DeadEvent($id)';
  }
}
