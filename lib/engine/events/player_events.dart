import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/vote_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 玩家死亡事件 - 公开可见
class DeadEvent extends GameEvent {
  final GamePlayer victim;
  final DeathCause cause;
  final GamePlayer? killer;
  final int? dayNumber;
  final GamePhase? phase;

  DeadEvent({
    required this.victim,
    required this.cause,
    this.killer,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'death_${victim.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.playerDeath,
         initiator: victim,
         target: killer,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    victim.setAlive(false);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'victim': victim.name,
      'cause': cause.name,
      'killer': killer?.name,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}

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

/// 发言事件 - 根据类型决定可见性
class SpeakEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;
  final SpeechType speechType;
  final int? dayNumber;
  final GamePhase? phase;

  SpeakEvent({
    required this.speaker,
    required this.message,
    this.speechType = SpeechType.normal,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'speak_${speaker.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.playerAction,
         initiator: speaker,
         visibility: _getDefaultVisibility(speechType),
         visibleToGameRole: speechType == SpeechType.werewolfDiscussion
             ? 'werewolf'
             : null,
       );

  static EventVisibility _getDefaultVisibility(SpeechType speechType) {
    switch (speechType) {
      case SpeechType.normal:
      case SpeechType.lastWords:
        return EventVisibility.public;
      case SpeechType.werewolfDiscussion:
        return EventVisibility.roleSpecific;
    }
  }

  @override
  void execute(GameState state) {
    // 发言事件不需要执行特殊逻辑，只是记录
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'speaker': speaker.name,
      'message': message,
      'speechType': speechType.name,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}

/// 狼人讨论事件 - 仅狼人可见
class WerewolfDiscussionEvent extends SpeakEvent {
  WerewolfDiscussionEvent({
    required super.speaker,
    required super.message,
    super.dayNumber,
    super.phase,
  }) : super(speechType: SpeechType.werewolfDiscussion);
}

/// 遗言事件 - 公开可见
class LastWordsEvent extends SpeakEvent {
  LastWordsEvent({
    required super.speaker,
    required super.message,
    super.dayNumber,
    super.phase,
  }) : super(speechType: SpeechType.lastWords);
}
