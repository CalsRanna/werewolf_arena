import 'game_state.dart';
import '../player/player.dart';

/// Helper function to safely convert dynamic to Player or null
Player? _toPlayer(dynamic obj) {
  if (obj is Player) return obj;
  return null;
}

/// Helper to extract player ID from dynamic object
String _getPlayerId(dynamic player) {
  return player.playerId as String;
}

/// Helper to extract player name from dynamic object
String _getPlayerName(dynamic player) {
  return player.name as String;
}

/// Base class for all game events that extend GameEvent
abstract class BaseGameEvent extends GameEvent {
  BaseGameEvent({
    required super.eventId,
    required super.type,
    required super.description,
    super.data,
    super.initiator,
    super.target,
    super.visibility,
    super.visibleToPlayerIds,
    super.visibleToRole,
  });

  /// Execute the event logic
  void execute(GameState state);
}

/// 死亡事件 - 所有人可见
class DeadEvent extends BaseGameEvent {
  DeadEvent({
    required dynamic player,
    required String cause,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'dead_${_getPlayerId(player)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerDeath,
          description: '${_getPlayerName(player)} 死亡: $cause',
          initiator: _toPlayer(player),
          visibility: EventVisibility.public,
          data: {
            'cause': cause,
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    if (initiator != null) {
      initiator!.isAlive = false;
    }
  }
}

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends BaseGameEvent {
  WerewolfKillEvent({
    required dynamic actor,
    required dynamic target,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'kill_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          description: '${_getPlayerName(actor)} 选择击杀 ${_getPlayerName(target)}',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.allWerewolves,
          data: {
            'skill': 'Kill',
            'targetId': _getPlayerId(target),
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    // Mark target for death (will be resolved at end of night)
    state.setTonightVictim(target);
  }
}

/// 守卫保护事件 - 仅守卫可见
class GuardProtectEvent extends BaseGameEvent {
  GuardProtectEvent({
    required dynamic actor,
    required dynamic target,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'protect_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          description: '${_getPlayerName(actor)} 守护了 ${_getPlayerName(target)}',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [_getPlayerId(actor)],
          data: {
            'skill': 'Protect',
            'targetId': _getPlayerId(target),
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    state.setTonightProtected(target);
    // Last guarded information is now tracked through event history
    // No need to store in private data
  }
}

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends BaseGameEvent {
  final String investigationResult;

  SeerInvestigateEvent({
    required dynamic actor,
    required dynamic target,
    required this.investigationResult,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'investigate_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          description: '${_getPlayerName(actor)} 查验了 ${_getPlayerName(target)}，结果是: $investigationResult',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [_getPlayerId(actor)],
          data: {
            'skill': 'Investigate',
            'targetId': _getPlayerId(target),
            'result': investigationResult,
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    // Investigation result is already stored in the event data
    // The seer will access this information through the event system
    // No need for private data storage
  }
}

/// 女巫救人事件 - 仅女巫可见
class WitchHealEvent extends BaseGameEvent {
  WitchHealEvent({
    required dynamic actor,
    required dynamic target,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'heal_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          description: '${_getPlayerName(actor)} 使用解药救了 ${_getPlayerName(target)}',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [_getPlayerId(actor)],
          data: {
            'skill': '使用解药',
            'targetId': _getPlayerId(target),
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    state.cancelTonightKill();
    // Antidote usage is now tracked through event history
    // No need to update private data
  }
}

/// 女巫毒杀事件 - 仅女巫可见
class WitchPoisonEvent extends BaseGameEvent {
  WitchPoisonEvent({
    required dynamic actor,
    required dynamic target,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'poison_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          description: '${_getPlayerName(actor)} 使用毒药毒杀了 ${_getPlayerName(target)}',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerIds: [_getPlayerId(actor)],
          data: {
            'skill': '使用毒药',
            'targetId': _getPlayerId(target),
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    state.setTonightPoisoned(target);
    // Poison usage is now tracked through event history
    // No need to update private data
  }
}

/// 投票事件 - 公开可见
class VoteEvent extends BaseGameEvent {
  VoteEvent({
    required dynamic actor,
    required dynamic target,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'vote_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.voteCast,
          description: '${_getPlayerName(actor)} 投票给 ${_getPlayerName(target)}',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.public,
          data: {
            'action': '投票',
            'targetId': _getPlayerId(target),
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    state.addVote(initiator!, target!);
  }
}

/// 发言事件 - 公开可见
class SpeakEvent extends BaseGameEvent {
  final String message;

  SpeakEvent({
    required dynamic actor,
    required this.message,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'speak_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerAction,
          description: '${_getPlayerName(actor)} 发言: $message',
          initiator: _toPlayer(actor),
          visibility: EventVisibility.public,
          data: {
            'type': 'speak',
            'message': message,
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    // Message content is already stored in event data
    // Players will access this through the event system
    // No need for separate message broadcasting
  }
}

/// 狼人讨论事件 - 仅狼人可见
class WerewolfDiscussionEvent extends BaseGameEvent {
  final String message;

  WerewolfDiscussionEvent({
    required dynamic actor,
    required this.message,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'werewolf_discussion_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.playerAction,
          description: '${_getPlayerName(actor)} 狼人讨论: $message',
          initiator: _toPlayer(actor),
          visibility: EventVisibility.roleSpecific,
          visibleToRole: 'werewolf',
          data: {
            'type': 'werewolf_discussion',
            'message': message,
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    // Message content is already stored in event data
    // Werewolves will access this through the event system with roleSpecific visibility
    // No need for separate message broadcasting
  }
}

/// 猎人开枪事件 - 公开可见
class HunterShootEvent extends BaseGameEvent {
  HunterShootEvent({
    required dynamic actor,
    required dynamic target,
    int? dayNumber,
    String? phase,
  }) : super(
          eventId: 'hunter_shoot_${_getPlayerId(actor)}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          description: '${_getPlayerName(actor)} 开枪带走了 ${_getPlayerName(target)}',
          initiator: _toPlayer(actor),
          target: _toPlayer(target),
          visibility: EventVisibility.public,
          data: {
            'skill': '开枪',
            'targetId': _getPlayerId(target),
            'dayNumber': dayNumber,
            'phase': phase,
          },
        );

  @override
  void execute(GameState state) {
    // Kill the target
    if (target != null) {
      target!.die('被猎人开枪带走', state);
    }
    // Hunter shoot status is now tracked through event history
    // No need to update private data
  }
}

/// 阶段转换事件 - 公开可见
class PhaseChangeEvent extends BaseGameEvent {
  final GamePhase oldPhase;
  final GamePhase newPhase;

  PhaseChangeEvent({
    required this.oldPhase,
    required this.newPhase,
    int? dayNumber,
  }) : super(
          eventId: 'phase_change_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.phaseChange,
          description: '游戏阶段从 ${oldPhase.name} 变为 ${newPhase.name}',
          visibility: EventVisibility.public,
          data: {
            'oldPhase': oldPhase.name,
            'newPhase': newPhase.name,
            'dayNumber': dayNumber,
          },
        );

  @override
  void execute(GameState state) {
    // Phase change is handled by GameState
  }
}

/// 游戏开始事件 - 公开可见
class GameStartEvent extends BaseGameEvent {
  GameStartEvent({
    required int playerCount,
    required Map<String, int> roleDistribution,
  }) : super(
          eventId: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.gameStart,
          description: '游戏开始，共 $playerCount 名玩家',
          visibility: EventVisibility.public,
          data: {
            'playerCount': playerCount,
            'roleDistribution': roleDistribution,
          },
        );

  @override
  void execute(GameState state) {
    // Game start logic is handled by GameState
  }
}

/// 游戏结束事件 - 公开可见
class GameEndEvent extends BaseGameEvent {
  final String winner;
  final int totalDays;
  final int finalPlayerCount;

  GameEndEvent({
    required this.winner,
    required this.totalDays,
    required this.finalPlayerCount,
    required DateTime startTime,
  }) : super(
          eventId: 'game_end_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.gameEnd,
          description: '游戏结束。获胜方: $winner',
          visibility: EventVisibility.public,
          data: {
            'winner': winner,
            'duration': DateTime.now().difference(startTime).inMilliseconds,
            'totalDays': totalDays,
            'finalPlayerCount': finalPlayerCount,
          },
        );

  @override
  void execute(GameState state) {
    // Game end logic is handled by GameState
  }
}