import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 玩家被投票出局事件 - 公开可见
class ExileEvent extends GameEvent {
  final GamePlayer victim;

  ExileEvent({required this.victim})
    : super(
        id: 'exile_${DateTime.now().millisecondsSinceEpoch}',
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
    return '${victim.name}被投票出局';
  }

  @override
  String toString() {
    return 'ExileEvent($id)';
  }
}
