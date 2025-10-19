import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 投票事件 - 公开可见
class VoteEvent extends GameEvent {
  final GamePlayer voter;
  final GamePlayer candidate;

  VoteEvent({required this.voter, required this.candidate})
    : super(
        id: 'vote_${voter.name}_${DateTime.now().millisecondsSinceEpoch}',
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
    return '第$dayNumber天，${voter.name}投票给了${candidate.name}';
  }

  @override
  String toString() {
    return 'VoteEvent($id)';
  }
}
