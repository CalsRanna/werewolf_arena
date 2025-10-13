import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/vote_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 投票事件 - 公开可见
class VoteEvent extends GameEvent {
  final GamePlayer voter;
  final GamePlayer candidate;
  final VoteType voteType;
  final int? dayNumber;
  final GamePhase? phase;

  VoteEvent({
    required this.voter,
    required this.candidate,
    this.voteType = VoteType.normal,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId: 'vote_${voter.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.voteCast,
         initiator: voter,
         target: candidate,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // Will be implemented when GameState is properly imported
    // state.addVote(voter, candidate);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'voter': voter.name,
      'candidate': candidate.name,
      'voteType': voteType.name,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}
