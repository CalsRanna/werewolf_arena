import 'package:werewolf_arena/core/engine/game_observer.dart';
import 'package:werewolf_arena/core/engine/game_state.dart';
import 'package:werewolf_arena/core/player/player.dart';
import 'package:werewolf_arena/core/engine/game_event.dart';
import 'console_output.dart';

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
    int finalPlayerCount,
  ) {
    _console.displayGameEnd(state, winner, totalDays, finalPlayerCount);
  }

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {
    _console.displayPhaseChange(oldPhase, newPhase, dayNumber);
  }

  @override
  void onPlayerAction(
    Player player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {
    _console.displayPlayerAction(player, actionType, target, details: details);
  }

  @override
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
    _console.displayPlayerDeath(player, cause, killer: killer);
  }

  @override
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType}) {
    _console.displayPlayerSpeak(player, message, speechType: speechType);
  }

  @override
  void onVoteCast(Player voter, Player target, {VoteType? voteType}) {
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
    _console.displayPlayerAction(
      voter,
      '投票',
      target,
      details: {'voteType': voteTypeText},
    );
  }

  @override
  void onNightResult(List<Player> deaths, bool isPeacefulNight, int dayNumber) {
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
    Player? executed,
    List<Player>? pkCandidates,
  ) {
    _console.displayVoteResults(results, executed, pkCandidates);
  }

  @override
  void onAlivePlayersAnnouncement(List<Player> alivePlayers) {
    _console.displayAlivePlayers(alivePlayers);
  }

  @override
  void onLastWords(Player player, String lastWords) {
    _console.displayLastWords(player, lastWords);
  }
}
