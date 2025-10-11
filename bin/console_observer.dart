import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_log_event.dart';
import 'console_output.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/vote_type.dart';

/// 控制台游戏观察者
///
/// 实现 GameObserver 接口，将游戏事件转换为控制台输出。
/// 这是游戏引擎与控制台显示之间的桥梁。
class ConsoleGameObserver extends GameObserverAdapter {
  final GameConsole _console = GameConsole.instance;

  @override
  void onGameStart(
    GameState state,
    int playerCount,
    Map<String, int> roleDistribution,
  ) {
    _console.displayGameStart(playerCount, roleDistribution);
  }

  @override
  void onGameEnd(
    GameState state,
    String winner,
    int totalDays,
    int finalGamePlayerCount,
  ) {
    _console.displayGameEnd(state, winner, totalDays, finalGamePlayerCount);
  }

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {
    _console.displayPhaseChange(oldPhase, newPhase, dayNumber);
  }

  @override
  void onGamePlayerAction(
    GamePlayer player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {
    _console.displayGamePlayerAction(
      player,
      actionType,
      target,
      details: details,
    );
  }

  @override
  void onGamePlayerDeath(
    GamePlayer player,
    DeathCause cause, {
    GamePlayer? killer,
  }) {
    _console.displayGamePlayerDeath(player, cause, killer: killer);
  }

  @override
  void onGamePlayerSpeak(
    GamePlayer player,
    String message, {
    SpeechType? speechType,
  }) {
    _console.displayGamePlayerSpeak(player, message, speechType: speechType);
  }

  @override
  void onVoteCast(GamePlayer voter, GamePlayer target, {VoteType? voteType}) {
    String voteTypeText = '';
    if (voteType != null) {
      switch (voteType) {
        case VoteType.normal:
          voteTypeText = ' (普通投票)';
          break;
        case VoteType.pk:
          voteTypeText = ' (PK投票)';
          break;
      }
    }
    _console.displayGamePlayerAction(
      voter,
      '投票',
      target,
      details: {'voteType': voteTypeText},
    );
  }

  @override
  void onNightResult(
    List<GamePlayer> deaths,
    bool isPeacefulNight,
    int dayNumber,
  ) {
    _console.displayNightResult(deaths, isPeacefulNight, dayNumber);
  }

  @override
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase}) {
    _console.displaySystemMessage(message, dayNumber: dayNumber, phase: phase);
  }

  @override
  void onErrorMessage(String error, {Object? errorDetails}) {
    _console.displayError(error, errorDetails: errorDetails);
  }

  @override
  void onVoteResults(
    Map<String, int> results,
    GamePlayer? executed,
    List<GamePlayer>? pkCandidates,
  ) {
    _console.displayVoteResults(results, executed, pkCandidates);
  }

  @override
  void onAliveGamePlayersAnnouncement(List<GamePlayer> aliveGamePlayers) {
    _console.displayAliveGamePlayers(aliveGamePlayers);
  }

  @override
  void onGameStateChanged(GameState state) {
    // 显示当前游戏状态摘要
    _console.printLine('📊 游戏状态更新:');
    _console.printLine('   阶段: ${_getPhaseDisplayName(state.currentPhase)}');
    _console.printLine('   第${state.dayNumber}天');
    _console.printLine('   存活玩家: ${state.alivePlayers.length}人');
    _console.printLine();
  }

  @override
  void onGameLog(GameLogEvent logEvent) {
    // 根据日志级别显示不同颜色
    switch (logEvent.level) {
      case GameLogLevel.error:
        _console.displayError('🔴 ${logEvent.message}');
        break;
      case GameLogLevel.warning:
        _console.printLine('🟡 ${logEvent.message}');
        break;
      case GameLogLevel.info:
        _console.printLine('ℹ️ ${logEvent.message}');
        break;
      case GameLogLevel.debug:
        // 只在调试模式下显示debug日志
        if (_isDebugMode()) {
          _console.printLine('🔍 [DEBUG] ${logEvent.message}');
        }
        break;
    }
  }

  /// 获取阶段显示名称
  String _getPhaseDisplayName(GamePhase phase) {
    switch (phase) {
      case GamePhase.night:
        return '🌙 夜晚';
      case GamePhase.day:
        return '☀️ 白天';
      case GamePhase.voting:
        return '🗳️ 投票';
      case GamePhase.ended:
        return '🏁 游戏结束';
    }
  }

  /// 检查是否为调试模式
  bool _isDebugMode() {
    // 可以通过环境变量或其他方式配置
    return const bool.fromEnvironment('DEBUG', defaultValue: false);
  }

  @override
  void onLastWords(GamePlayer player, String lastWords) {
    _console.displayLastWords(player, lastWords);
  }
}
