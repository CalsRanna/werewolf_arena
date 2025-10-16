import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 投票事件 - 公开可见
class VoteEvent extends GameEvent {
  final GamePlayer voter;
  final GamePlayer candidate;
  final int? dayNumber;
  final GamePhase? phase;

  VoteEvent({
    required this.voter,
    required this.candidate,
    this.dayNumber,
    this.phase,
  }) : super(
         id: 'vote_${voter.name}_${DateTime.now().millisecondsSinceEpoch}',
         visibility: [
           'villager',
           'werewolf',
           'seer',
           'witch',
           'hunter',
           'guardian',
         ],
       );

  @override
  String toString() {
    return 'VoteEvent(id: $id)';
  }
}
