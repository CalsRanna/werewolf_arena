import '../state/game_state.dart';
import '../entities/player/player.dart';
import '../state/game_event.dart';

/// 游戏事件回调接口
///
/// 这个接口定义了游戏引擎与外部系统（如UI、日志系统等）之间的通信协议。
/// 通过这个接口，游戏引擎可以通知外部系统游戏中发生的各种事件，
/// 而不直接依赖具体的输出实现。
abstract class GameEventCallbacks {
  /// 游戏开始
  void onGameStart(GameState state, int playerCount, Map<String, int> roleDistribution);

  /// 游戏结束
  void onGameEnd(GameState state, String winner, int totalDays, int finalPlayerCount);

  /// 阶段转换
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber);

  /// 玩家行动
  void onPlayerAction(Player player, String actionType, dynamic target, {Map<String, dynamic>? details});

  /// 玩家死亡
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer});

  /// 玩家发言
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType});

  /// 投票事件
  void onVoteCast(Player voter, Player target, {VoteType? voteType});

  /// 夜晚结果公告
  void onNightResult(List<Player> deaths, bool isPeacefulNight, int dayNumber);

  /// 系统消息（法官公告等）
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase});

  /// 错误消息
  void onErrorMessage(String error, {Object? errorDetails});

  /// 游戏状态更新
  void onGameStateChanged(GameState state);

  /// 投票结果统计
  void onVoteResults(Map<String, int> results, Player? executed, List<Player>? pkCandidates);

  /// 存活玩家公告
  void onAlivePlayersAnnouncement(List<Player> alivePlayers);

  /// 遗言
  void onLastWords(Player player, String lastWords);
}

/// 简单的回调适配器，提供空实现
///
/// 实现类可以选择性地重写需要的方法，而不用实现所有方法
abstract class GameEventCallbacksAdapter implements GameEventCallbacks {
  @override
  void onGameStart(GameState state, int playerCount, Map<String, int> roleDistribution) {}

  @override
  void onGameEnd(GameState state, String winner, int totalDays, int finalPlayerCount) {}

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {}

  @override
  void onPlayerAction(Player player, String actionType, dynamic target, {Map<String, dynamic>? details}) {}

  @override
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {}

  @override
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType}) {}

  @override
  void onVoteCast(Player voter, Player target, {VoteType? voteType}) {}

  @override
  void onNightResult(List<Player> deaths, bool isPeacefulNight, int dayNumber) {}

  @override
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase}) {}

  @override
  void onErrorMessage(String error, {Object? errorDetails}) {}

  @override
  void onGameStateChanged(GameState state) {}

  @override
  void onVoteResults(Map<String, int> results, Player? executed, List<Player>? pkCandidates) {}

  @override
  void onAlivePlayersAnnouncement(List<Player> alivePlayers) {}

  @override
  void onLastWords(Player player, String lastWords) {}
}

/// 复合回调处理器，可以同时处理多个回调实现
///
/// 允许多个回调处理器同时监听游戏事件
class CompositeGameEventCallbacks implements GameEventCallbacks {
  final List<GameEventCallbacks> _callbacks = [];

  /// 添加回调处理器
  void addCallback(GameEventCallbacks callback) {
    _callbacks.add(callback);
  }

  /// 移除回调处理器
  void removeCallback(GameEventCallbacks callback) {
    _callbacks.remove(callback);
  }

  /// 清空所有回调处理器
  void clearCallbacks() {
    _callbacks.clear();
  }

  @override
  void onGameStart(GameState state, int playerCount, Map<String, int> roleDistribution) {
    for (final callback in _callbacks) {
      callback.onGameStart(state, playerCount, roleDistribution);
    }
  }

  @override
  void onGameEnd(GameState state, String winner, int totalDays, int finalPlayerCount) {
    for (final callback in _callbacks) {
      callback.onGameEnd(state, winner, totalDays, finalPlayerCount);
    }
  }

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {
    for (final callback in _callbacks) {
      callback.onPhaseChange(oldPhase, newPhase, dayNumber);
    }
  }

  @override
  void onPlayerAction(Player player, String actionType, dynamic target, {Map<String, dynamic>? details}) {
    for (final callback in _callbacks) {
      callback.onPlayerAction(player, actionType, target, details: details);
    }
  }

  @override
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
    for (final callback in _callbacks) {
      callback.onPlayerDeath(player, cause, killer: killer);
    }
  }

  @override
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType}) {
    for (final callback in _callbacks) {
      callback.onPlayerSpeak(player, message, speechType: speechType);
    }
  }

  @override
  void onVoteCast(Player voter, Player target, {VoteType? voteType}) {
    for (final callback in _callbacks) {
      callback.onVoteCast(voter, target, voteType: voteType);
    }
  }

  @override
  void onNightResult(List<Player> deaths, bool isPeacefulNight, int dayNumber) {
    for (final callback in _callbacks) {
      callback.onNightResult(deaths, isPeacefulNight, dayNumber);
    }
  }

  @override
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase}) {
    for (final callback in _callbacks) {
      callback.onSystemMessage(message, dayNumber: dayNumber, phase: phase);
    }
  }

  @override
  void onErrorMessage(String error, {Object? errorDetails}) {
    for (final callback in _callbacks) {
      callback.onErrorMessage(error, errorDetails: errorDetails);
    }
  }

  @override
  void onGameStateChanged(GameState state) {
    for (final callback in _callbacks) {
      callback.onGameStateChanged(state);
    }
  }

  @override
  void onVoteResults(Map<String, int> results, Player? executed, List<Player>? pkCandidates) {
    for (final callback in _callbacks) {
      callback.onVoteResults(results, executed, pkCandidates);
    }
  }

  @override
  void onAlivePlayersAnnouncement(List<Player> alivePlayers) {
    for (final callback in _callbacks) {
      callback.onAlivePlayersAnnouncement(alivePlayers);
    }
  }

  @override
  void onLastWords(Player player, String lastWords) {
    for (final callback in _callbacks) {
      callback.onLastWords(player, lastWords);
    }
  }
}