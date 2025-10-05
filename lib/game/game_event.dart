import 'game_state.dart';
import '../player/player.dart';
import '../player/role.dart';

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

/// 游戏状态事件类型
enum GameStateEventType {
  start,
  end,
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
          eventId: 'death_${victim.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerDeath,
          initiator: victim,
          target: killer,
          visibility: EventVisibility.public,
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'victimId': victim.playerId,
      'victimName': victim.name,
      'victimRole': victim.role.roleId,
      'cause': cause.toString(),
      'killerId': killer?.playerId,
      'killerName': killer?.name,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    final causeText = _getCauseText(cause, locale);
    return '${victim.name} $causeText';
  }

  @override
  String getDescriptionForPlayer(dynamic player, {String? locale}) {
    // 根据玩家身份决定显示多少细节
    final canSeeDeathCause = _canSeeDeathCause(player);

    if (canSeeDeathCause) {
      return generateDescription(locale: locale);
    } else {
      // 隐藏死因，只显示基本信息
      return '${victim.name} 死亡';
    }
  }

  bool _canSeeDeathCause(dynamic player) {
    final playerId = player.playerId as String;
    final role = player.role as Role;
    final isAlive = player.isAlive as bool;

    return role.isWerewolf ||
           role.roleId == 'witch' ||
           playerId == victim.playerId ||
           !isAlive; // 死人知道一切
  }

  String _getCauseText(DeathCause cause, String? locale) {
    switch (cause) {
      case DeathCause.werewolfKill:
        return '被狼人杀死';
      case DeathCause.vote:
        return '被投票处决';
      case DeathCause.poison:
        return '被毒死';
      case DeathCause.hunterShot:
        return '被猎人击毙';
      case DeathCause.other:
        return '死亡';
    }
  }

  @override
  void execute(GameState state) {
    victim.isAlive = false;
  }
}

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends GameEvent {
  final Player actor;
  final Player target;
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfKillEvent({
    required this.actor,
    required this.target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'kill_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.allWerewolves,
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'actorId': actor.playerId,
      'actorName': actor.name,
      'actorRole': actor.role.roleId,
      'skillType': SkillType.werewolfKill.toString(),
      'targetId': target.playerId,
      'targetName': target.name,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '${actor.name} 选择击杀 ${target.name}';
  }

  @override
  void execute(GameState state) {
    // Mark target for death (will be resolved at end of night)
    state.setTonightVictim(target);
  }
}

/// 守卫保护事件 - 仅守卫可见
class GuardProtectEvent extends GameEvent {
  final Player actor;
  final Player target;
  final int? dayNumber;
  final GamePhase? phase;

  GuardProtectEvent({
    required this.actor,
    required this.target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'protect_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [actor.playerId],
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'actorId': actor.playerId,
      'actorName': actor.name,
      'actorRole': actor.role.roleId,
      'skillType': SkillType.guardProtect.toString(),
      'targetId': target.playerId,
      'targetName': target.name,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '${actor.name} 守护了 ${target.name}';
  }

  @override
  void execute(GameState state) {
    state.setTonightProtected(target);
  }
}

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends GameEvent {
  final Player actor;
  final Player target;
  final String investigationResult;
  final int? dayNumber;
  final GamePhase? phase;

  SeerInvestigateEvent({
    required this.actor,
    required this.target,
    required this.investigationResult,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'investigate_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [actor.playerId],
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'actorId': actor.playerId,
      'actorName': actor.name,
      'actorRole': actor.role.roleId,
      'skillType': SkillType.seerInvestigate.toString(),
      'targetId': target.playerId,
      'targetName': target.name,
      'result': investigationResult,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '${actor.name} 查验了 ${target.name}，结果是: $investigationResult';
  }

  @override
  void execute(GameState state) {
    // Investigation result is already stored in the event data
    // The seer will access this information through the event system
  }
}

/// 女巫救人事件 - 仅女巫可见
class WitchHealEvent extends GameEvent {
  final Player actor;
  final Player target;
  final int? dayNumber;
  final GamePhase? phase;

  WitchHealEvent({
    required this.actor,
    required this.target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'heal_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [actor.playerId],
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'actorId': actor.playerId,
      'actorName': actor.name,
      'actorRole': actor.role.roleId,
      'skillType': SkillType.witchHeal.toString(),
      'targetId': target.playerId,
      'targetName': target.name,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '${actor.name} 使用解药救了 ${target.name}';
  }

  @override
  void execute(GameState state) {
    state.cancelTonightKill();
  }
}

/// 女巫毒杀事件 - 仅女巫可见
class WitchPoisonEvent extends GameEvent {
  final Player actor;
  final Player target;
  final int? dayNumber;
  final GamePhase? phase;

  WitchPoisonEvent({
    required this.actor,
    required this.target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'poison_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [actor.playerId],
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'actorId': actor.playerId,
      'actorName': actor.name,
      'actorRole': actor.role.roleId,
      'skillType': SkillType.witchPoison.toString(),
      'targetId': target.playerId,
      'targetName': target.name,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '${actor.name} 使用毒药毒杀了 ${target.name}';
  }

  @override
  void execute(GameState state) {
    state.setTonightPoisoned(target);
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
          eventId: 'vote_${voter.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.voteCast,
          initiator: voter,
          target: candidate,
          visibility: EventVisibility.public,
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'voterId': voter.playerId,
      'voterName': voter.name,
      'candidateId': candidate.playerId,
      'candidateName': candidate.name,
      'voteType': voteType.toString(),
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    final voteText = _getVoteText(voteType, locale);
    return '${voter.name} $voteText ${candidate.name}';
  }

  String _getVoteText(VoteType voteType, String? locale) {
    switch (voteType) {
      case VoteType.normal:
        return '投票给';
      case VoteType.pk:
        return 'PK投票给';
    }
  }

  @override
  void execute(GameState state) {
    state.addVote(voter, candidate);
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
          eventId: 'speak_${speaker.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerAction,
          initiator: speaker,
          visibility: _getDefaultVisibility(speechType),
          visibleToRole: speechType == SpeechType.werewolfDiscussion ? 'werewolf' : null,
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
  Map<String, dynamic> getStructuredData() {
    return {
      'speakerId': speaker.playerId,
      'speakerName': speaker.name,
      'message': message,
      'speechType': speechType.toString(),
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    final speechText = _getSpeechText(speechType, locale);
    return '${speaker.name} $speechText: $message';
  }

  String _getSpeechText(SpeechType speechType, String? locale) {
    switch (speechType) {
      case SpeechType.normal:
        return '发言';
      case SpeechType.lastWords:
        return '遗言';
      case SpeechType.werewolfDiscussion:
        return '狼人讨论';
    }
  }

  @override
  void execute(GameState state) {
    // 发言事件不需要执行特殊逻辑，只是记录
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
  final Player target;
  final int? dayNumber;
  final GamePhase? phase;

  HunterShootEvent({
    required this.actor,
    required this.target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'hunter_shoot_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.public,
        );

  @override
  Map<String, dynamic> getStructuredData() {
    return {
      'actorId': actor.playerId,
      'actorName': actor.name,
      'actorRole': actor.role.roleId,
      'skillType': SkillType.hunterShoot.toString(),
      'targetId': target.playerId,
      'targetName': target.name,
      'dayNumber': dayNumber,
      'phase': phase?.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '${actor.name} 开枪带走了 ${target.name}';
  }

  @override
  void execute(GameState state) {
    // Create death event for the target
    final deathEvent = DeadEvent(
      victim: target,
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
  Map<String, dynamic> getStructuredData() {
    return {
      'oldPhase': oldPhase.toString(),
      'newPhase': newPhase.toString(),
      'dayNumber': dayNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    final oldPhaseText = _getPhaseText(oldPhase, locale);
    final newPhaseText = _getPhaseText(newPhase, locale);
    return '游戏阶段从 $oldPhaseText 变为 $newPhaseText';
  }

  String _getPhaseText(GamePhase phase, String? locale) {
    switch (phase) {
      case GamePhase.night:
        return '夜晚';
      case GamePhase.day:
        return '白天';
      case GamePhase.voting:
        return '投票';
      case GamePhase.ended:
        return '结束';
    }
  }

  @override
  void execute(GameState state) {
    // 阶段转换由GameState处理
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
  Map<String, dynamic> getStructuredData() {
    return {
      'deathEvents': deathEvents.map((e) => e.getStructuredData()).toList(),
      'isPeacefulNight': isPeacefulNight,
      'dayNumber': dayNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    if (isPeacefulNight) {
      return '昨晚是平安夜，没有人死亡';
    } else {
      final deathMessages = deathEvents.map((e) => e.generateDescription()).join(', ');
      return '昨晚有人死亡: $deathMessages';
    }
  }

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
  Map<String, dynamic> getStructuredData() {
    return {
      'playerCount': playerCount,
      'roleDistribution': roleDistribution,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '游戏开始，共 $playerCount 名玩家';
  }

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
  Map<String, dynamic> getStructuredData() {
    return {
      'winner': winner,
      'duration': DateTime.now().difference(gameStartTime).inMilliseconds,
      'totalDays': totalDays,
      'finalPlayerCount': finalPlayerCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '游戏结束。获胜方: $winner';
  }

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
  Map<String, dynamic> getStructuredData() {
    return {
      'errorMessage': errorMessage,
      'error': error.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String generateDescription({String? locale}) {
    return '游戏错误: $errorMessage';
  }

  @override
  void execute(GameState state) {
    // Error events don't modify game state
  }
}