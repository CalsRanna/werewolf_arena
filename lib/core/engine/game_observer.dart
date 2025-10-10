import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/vote_type.dart';

/// 游戏观察者接口
///
/// 这个接口定义了游戏引擎与外部系统（如UI、日志系统等）之间的通信协议。
/// 通过这个接口，游戏引擎可以通知外部系统游戏中发生的各种事件，
/// 而不直接依赖具体的输出实现。
///
/// 使用示例：
/// ```dart
/// // 1. 直接实现观察者接口（需要实现所有14个方法）
/// class MyGameObserver implements GameObserver {
///   @override
///   void onGameStart(GameState state, int playerCount, Map<String, int> roleDistribution) {
///     print('游戏开始: $playerCount 个玩家');
///   }
///
///   @override
///   void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
///     print('${player.name} 死亡');
///   }
///
///   // ... 实现其他所有方法
/// }
///
/// // 2. 使用观察者
/// final engine = GameEngine(
///   parameters: myGameParameters,
///   observer: MyGameObserver(),
/// );
/// ```
abstract class GameObserver {
  /// 游戏开始
  void onGameStart(
    GameState state,
    int playerCount,
    Map<String, int> roleDistribution,
  );

  /// 游戏结束
  void onGameEnd(
    GameState state,
    String winner,
    int totalDays,
    int finalPlayerCount,
  );

  /// 阶段转换
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber);

  /// 玩家行动
  void onPlayerAction(
    Player player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  });

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
  void onVoteResults(
    Map<String, int> results,
    Player? executed,
    List<Player>? pkCandidates,
  );

  /// 存活玩家公告
  void onAlivePlayersAnnouncement(List<Player> alivePlayers);

  /// 遗言
  void onLastWords(Player player, String lastWords);
}

/// 简单的观察者适配器，提供空实现
///
/// 实现类可以选择性地重写需要的方法，而不用实现所有方法。
/// 这样可以避免在只需要处理少数事件时实现所有14个接口方法。
///
/// 使用示例：
/// ```dart
/// // 只关注玩家死亡和游戏结束事件
/// class DeathTracker extends GameObserverAdapter {
///   final List<Player> deadPlayers = [];
///
///   @override
///   void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
///     deadPlayers.add(player);
///     print('${player.name} 死亡，原因：$cause');
///   }
///
///   @override
///   void onGameEnd(GameState state, String winner, int totalDays, int finalPlayerCount) {
///     print('游戏结束，共有 ${deadPlayers.length} 人死亡');
///   }
///
///   // 不需要实现其他12个方法
/// }
///
/// final engine = GameEngine(
///   parameters: myGameParameters,
///   observer: DeathTracker(),
/// );
/// ```
abstract class GameObserverAdapter implements GameObserver {
  @override
  void onGameStart(
    GameState state,
    int playerCount,
    Map<String, int> roleDistribution,
  ) {}

  @override
  void onGameEnd(
    GameState state,
    String winner,
    int totalDays,
    int finalPlayerCount,
  ) {}

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {}

  @override
  void onPlayerAction(
    Player player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {}

  @override
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {}

  @override
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType}) {}

  @override
  void onVoteCast(Player voter, Player target, {VoteType? voteType}) {}

  @override
  void onNightResult(
    List<Player> deaths,
    bool isPeacefulNight,
    int dayNumber,
  ) {}

  @override
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase}) {}

  @override
  void onErrorMessage(String error, {Object? errorDetails}) {}

  @override
  void onGameStateChanged(GameState state) {}

  @override
  void onVoteResults(
    Map<String, int> results,
    Player? executed,
    List<Player>? pkCandidates,
  ) {}

  @override
  void onAlivePlayersAnnouncement(List<Player> alivePlayers) {}

  @override
  void onLastWords(Player player, String lastWords) {}
}

/// 复合观察者，可以同时处理多个观察者实现
///
/// 允许多个观察者同时监听游戏事件。
/// 提供错误隔离：单个观察者的错误不会影响其他观察者的执行。
///
/// 使用示例：
/// ```dart
/// // 创建多个观察者
/// final consoleObserver = ConsoleGameObserver();
/// final streamObserver = StreamGameObserver();
/// final analyticsObserver = GameAnalyticsObserver();
///
/// // 使用复合观察者组合它们
/// final composite = CompositeGameObserver()
///   ..addObserver(consoleObserver)
///   ..addObserver(streamObserver)
///   ..addObserver(analyticsObserver);
///
/// // 传递给游戏引擎
/// final engine = GameEngine(
///   parameters: myGameParameters,
///   observer: composite,
/// );
///
/// // 现在所有三个观察者都会收到游戏事件
/// // 如果其中一个观察者抛出异常，其他观察者仍会继续工作
/// ```
class CompositeGameObserver implements GameObserver {
  final List<GameObserver> _observers = [];

  /// 添加观察者
  void addObserver(GameObserver observer) {
    _observers.add(observer);
  }

  /// 移除观察者
  void removeObserver(GameObserver observer) {
    _observers.remove(observer);
  }

  /// 清空所有观察者
  void clearObservers() {
    _observers.clear();
  }

  /// 安全地通知所有观察者，捕获并记录单个观察者的错误
  void _notifyObservers(void Function(GameObserver) action, String eventName) {
    for (final observer in _observers) {
      try {
        action(observer);
      } catch (e, stackTrace) {
        // 记录错误但继续通知其他观察者
        print('警告: 观察者 ${observer.runtimeType} 在处理 $eventName 时发生错误: $e');
        print('堆栈跟踪: $stackTrace');
      }
    }
  }

  @override
  void onGameStart(
    GameState state,
    int playerCount,
    Map<String, int> roleDistribution,
  ) {
    _notifyObservers(
      (observer) => observer.onGameStart(state, playerCount, roleDistribution),
      'onGameStart',
    );
  }

  @override
  void onGameEnd(
    GameState state,
    String winner,
    int totalDays,
    int finalPlayerCount,
  ) {
    _notifyObservers(
      (observer) =>
          observer.onGameEnd(state, winner, totalDays, finalPlayerCount),
      'onGameEnd',
    );
  }

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {
    _notifyObservers(
      (observer) => observer.onPhaseChange(oldPhase, newPhase, dayNumber),
      'onPhaseChange',
    );
  }

  @override
  void onPlayerAction(
    Player player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {
    _notifyObservers(
      (observer) =>
          observer.onPlayerAction(player, actionType, target, details: details),
      'onPlayerAction',
    );
  }

  @override
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
    _notifyObservers(
      (observer) => observer.onPlayerDeath(player, cause, killer: killer),
      'onPlayerDeath',
    );
  }

  @override
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType}) {
    _notifyObservers(
      (observer) =>
          observer.onPlayerSpeak(player, message, speechType: speechType),
      'onPlayerSpeak',
    );
  }

  @override
  void onVoteCast(Player voter, Player target, {VoteType? voteType}) {
    _notifyObservers(
      (observer) => observer.onVoteCast(voter, target, voteType: voteType),
      'onVoteCast',
    );
  }

  @override
  void onNightResult(List<Player> deaths, bool isPeacefulNight, int dayNumber) {
    _notifyObservers(
      (observer) => observer.onNightResult(deaths, isPeacefulNight, dayNumber),
      'onNightResult',
    );
  }

  @override
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase}) {
    _notifyObservers(
      (observer) =>
          observer.onSystemMessage(message, dayNumber: dayNumber, phase: phase),
      'onSystemMessage',
    );
  }

  @override
  void onErrorMessage(String error, {Object? errorDetails}) {
    _notifyObservers(
      (observer) => observer.onErrorMessage(error, errorDetails: errorDetails),
      'onErrorMessage',
    );
  }

  @override
  void onGameStateChanged(GameState state) {
    _notifyObservers(
      (observer) => observer.onGameStateChanged(state),
      'onGameStateChanged',
    );
  }

  @override
  void onVoteResults(
    Map<String, int> results,
    Player? executed,
    List<Player>? pkCandidates,
  ) {
    _notifyObservers(
      (observer) => observer.onVoteResults(results, executed, pkCandidates),
      'onVoteResults',
    );
  }

  @override
  void onAlivePlayersAnnouncement(List<Player> alivePlayers) {
    _notifyObservers(
      (observer) => observer.onAlivePlayersAnnouncement(alivePlayers),
      'onAlivePlayersAnnouncement',
    );
  }

  @override
  void onLastWords(Player player, String lastWords) {
    _notifyObservers(
      (observer) => observer.onLastWords(player, lastWords),
      'onLastWords',
    );
  }
}
