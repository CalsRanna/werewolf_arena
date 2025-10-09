import 'game_state.dart';
import 'package:werewolf_arena/core/entities/player/player.dart';

/// 死亡原因枚举
enum DeathCause {
  werewolfKill,
  vote,
  poison,
  hunterShot,
  other,
}

/// 技能类型枚举
enum SkillType {
  werewolfKill,
  guardProtect,
  seerInvestigate,
  witchHeal,
  witchPoison,
  hunterShoot,
}

/// 投票类型枚举
enum VoteType {
  normal,
  pk,
}

/// 发言类型枚举
enum SpeechType {
  normal,
  lastWords,
  werewolfDiscussion,
}

/// 玩家死亡事件 - 完全结构化
class DeadEvent extends GameEvent {
  final Player victim;
  final DeathCause cause;
  final Player? killer; // 可选：造成死亡的玩家
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
    victim.isAlive = false;
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

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends GameEvent {
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfKillEvent({
    required this.actor,
    required Player target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'kill_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.allWerewolves,
        );
  
  @override
  void execute(GameState state) {
    // Mark target for death (will be resolved at end of night)
    state.setTonightVictim(target!);
  }
}

/// 守卫保护事件 - 仅守卫可见
class GuardProtectEvent extends GameEvent {
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  GuardProtectEvent({
    required this.actor,
    required Player target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'protect_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );
  
  @override
  void execute(GameState state) {
    state.setTonightProtected(target!);
  }
}

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends GameEvent {
  final Player actor;
  final String investigationResult;
  final int? dayNumber;
  final GamePhase? phase;

  SeerInvestigateEvent({
    required this.actor,
    required Player target,
    required this.investigationResult,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'investigate_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );
  
  @override
  void execute(GameState state) {
    // Investigation result is already stored in the event data
    // The seer will access this information through the event system
  }
}

/// 女巫救人事件 - 仅女巫可见
class WitchHealEvent extends GameEvent {
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchHealEvent({
    required this.actor,
    required Player target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'heal_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );
  
  @override
  void execute(GameState state) {
    state.cancelTonightKill();
  }
}

/// 女巫毒杀事件 - 仅女巫可见
class WitchPoisonEvent extends GameEvent {
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchPoisonEvent({
    required this.actor,
    required Player target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'poison_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );
  
  @override
  void execute(GameState state) {
    state.setTonightPoisoned(target!);
  }
}

/// 法官公告事件 - 公开可见，用于通知所有玩家公共信息
class JudgeAnnouncementEvent extends GameEvent {
  final String announcement;
  final int? dayNumber;
  final GamePhase? phase;

  JudgeAnnouncementEvent({
    required this.announcement,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'announcement_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.phaseChange, // 使用phaseChange类型作为公告
          visibility: EventVisibility.public,
        );

  @override
  void execute(GameState state) {
    // 公告事件不需要执行具体逻辑，只是传递信息
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'announcement': announcement,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }

  @override
  String toString() {
    return 'JudgeAnnouncement: $announcement';
  }
}

/// 投票事件 - 公开可见
class VoteEvent extends GameEvent {
  final Player voter;
  final Player candidate;
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
          eventId:
              'vote_${voter.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.voteCast,
          initiator: voter,
          target: candidate,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    state.addVote(voter, candidate);
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

/// 发言事件 - 公开可见
class SpeakEvent extends GameEvent {
  final Player speaker;
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
          visibleToRole:
              speechType == SpeechType.werewolfDiscussion ? 'werewolf' : null,
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
  }) : super(
          speechType: SpeechType.werewolfDiscussion,
        );
}

/// 猎人开枪事件 - 公开可见
class HunterShootEvent extends GameEvent {
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  HunterShootEvent({
    required this.actor,
    required Player target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'hunter_shoot_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    // Create death event for the target
    final deathEvent = DeadEvent(
      victim: target!,
      cause: DeathCause.hunterShot,
      killer: actor,
      dayNumber: dayNumber,
      phase: phase,
    );
    deathEvent.execute(state);
    state.addEvent(deathEvent);
  }
}

/// 阶段转换事件 - 公开可见
class PhaseChangeEvent extends GameEvent {
  final GamePhase oldPhase;
  final GamePhase newPhase;
  final int dayNumber;

  PhaseChangeEvent({
    required this.oldPhase,
    required this.newPhase,
    required this.dayNumber,
  }) : super(
          eventId: 'phase_change_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.phaseChange,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    // 阶段转换由GameState处理
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'oldPhase': oldPhase.name,
      'newPhase': newPhase.name,
      'dayNumber': dayNumber,
    };
  }
}

/// 夜晚结果公告事件 - 公开可见
class NightResultEvent extends GameEvent {
  final List<DeadEvent> deathEvents;
  final bool isPeacefulNight;
  final int dayNumber;

  NightResultEvent({
    required this.deathEvents,
    required this.isPeacefulNight,
    required this.dayNumber,
  }) : super(
          eventId: 'night_result_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.dayBreak,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    // Night result announcement is handled by GameEngine
    // This event just provides information to players
  }
}

/// 游戏开始事件 - 公开可见
class GameStartEvent extends GameEvent {
  final int playerCount;
  final Map<String, int> roleDistribution;

  GameStartEvent({
    required this.playerCount,
    required this.roleDistribution,
  }) : super(
          eventId: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.gameStart,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    // Game start logic is handled by GameState
  }
}

/// 遗言事件 - 公开可见
class LastWordsEvent extends SpeakEvent {
  LastWordsEvent({
    required super.speaker,
    required super.message,
    super.dayNumber,
    super.phase,
  }) : super(
          speechType: SpeechType.lastWords,
        );
}

/// 游戏结束事件 - 公开可见
class GameEndEvent extends GameEvent {
  final String winner;
  final int totalDays;
  final int finalPlayerCount;
  final DateTime gameStartTime;

  GameEndEvent({
    required this.winner,
    required this.totalDays,
    required this.finalPlayerCount,
    required this.gameStartTime,
  }) : super(
          eventId: 'game_end_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.gameEnd,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    // Game end logic is handled by GameState
  }
}

/// 系统错误事件 - 公开可见
class SystemErrorEvent extends GameEvent {
  final String errorMessage;
  final dynamic error;

  SystemErrorEvent({
    required this.errorMessage,
    required this.error,
  }) : super(
          eventId: 'error_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerAction,
          visibility: EventVisibility.public,
        );
  
  @override
  void execute(GameState state) {
    // Error events don't modify game state
  }
}

/// 发言顺序公告事件 - 公开可见
class SpeechOrderAnnouncementEvent extends GameEvent {
  final List<Player> speakingOrder;
  final int dayNumber;
  final String direction; // "顺序" 或 "逆序"

  SpeechOrderAnnouncementEvent({
    required this.speakingOrder,
    required this.dayNumber,
    required this.direction,
  }) : super(
          eventId:
              'speech_order_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerAction,
          visibility: EventVisibility.public,
        );

  
  @override
  void execute(GameState state) {
    // 发言顺序公告不需要修改游戏状态
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'speakingOrder': speakingOrder.map((p) => p.name).toList(),
      'dayNumber': dayNumber,
      'direction': direction,
    };
  }
}
