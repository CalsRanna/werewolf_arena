import 'dart:async';
import 'package:werewolf_arena/core/engine/game_observer.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/vote_type.dart';

/// 基于 Stream 的游戏观察者
///
/// 将游戏事件转换为 Dart Stream，适用于 Flutter UI 层监听游戏状态变化。
/// 这是一个纯粹的观察者实现，只负责事件到 Stream 的转换，不包含业务逻辑。
///
/// 使用示例：
/// ```dart
/// final observer = StreamGameObserver();
///
/// // 监听特定事件
/// observer.gameStartStream.listen((_) {
///   print('游戏开始了！');
/// });
///
/// observer.playerActionStream.listen((message) {
///   print('玩家行动: $message');
/// });
///
/// // 传递给游戏引擎
/// final engine = GameEngine(
///   configManager: configManager,
///   observer: observer,
/// );
/// ```
class StreamGameObserver implements GameObserver {
  // 事件流控制器
  final StreamController<String> _gameEventController =
      StreamController.broadcast();
  final StreamController<void> _onGameStartController =
      StreamController.broadcast();
  final StreamController<String> _onPhaseChangeController =
      StreamController.broadcast();
  final StreamController<String> _onPlayerActionController =
      StreamController.broadcast();
  final StreamController<String> _onGameEndController =
      StreamController.broadcast();
  final StreamController<String> _onErrorController =
      StreamController.broadcast();
  final StreamController<GameState> _onGameStateChangedController =
      StreamController.broadcast();

  // 公开的事件流
  Stream<String> get gameEvents => _gameEventController.stream;
  Stream<void> get gameStartStream => _onGameStartController.stream;
  Stream<String> get phaseChangeStream => _onPhaseChangeController.stream;
  Stream<String> get playerActionStream => _onPlayerActionController.stream;
  Stream<String> get gameEndStream => _onGameEndController.stream;
  Stream<String> get errorStream => _onErrorController.stream;
  Stream<GameState> get gameStateChangedStream =>
      _onGameStateChangedController.stream;

  @override
  void onGameStart(
    GameState state,
    int playerCount,
    Map<String, int> roleDistribution,
  ) {
    final rolesStr = roleDistribution.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    _gameEventController.add('游戏开始 - 玩家数: $playerCount, 角色分布: $rolesStr');
    _onGameStartController.add(null);
  }

  @override
  void onGameEnd(
    GameState state,
    String winner,
    int totalDays,
    int finalPlayerCount,
  ) {
    _gameEventController.add('游戏结束 - 获胜方: $winner, 总天数: $totalDays');
    _onGameEndController.add('游戏结束: $winner 获胜');
  }

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase, int dayNumber) {
    final phaseStr = _getPhaseString(newPhase);
    _gameEventController.add(
      '阶段变更: ${_getPhaseString(oldPhase)} -> $phaseStr (第${dayNumber}天)',
    );
    _onPhaseChangeController.add(phaseStr);
  }

  @override
  void onPlayerAction(
    GamePlayer player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {
    final targetStr = target is GamePlayer ? target.name : target.toString();
    var message = '${player.name} 执行 $actionType -> $targetStr';
    if (details != null && details.isNotEmpty) {
      message +=
          ' (${details.entries.map((e) => '${e.key}: ${e.value}').join(', ')})';
    }
    _gameEventController.add(message);
    _onPlayerActionController.add(message);
  }

  @override
  void onPlayerDeath(GamePlayer player, DeathCause cause, {GamePlayer? killer}) {
    final causeStr = _getDeathCauseString(cause);
    var message = '${player.name} 死亡 ($causeStr)';
    if (killer != null) {
      message += ' - 凶手: ${killer.name}';
    }
    _gameEventController.add(message);
  }

  @override
  void onPlayerSpeak(GamePlayer player, String message, {SpeechType? speechType}) {
    final typeStr = speechType != null
        ? '[${_getSpeechTypeString(speechType)}]'
        : '';
    _gameEventController.add('$typeStr${player.name}: $message');
  }

  @override
  void onVoteCast(GamePlayer voter, GamePlayer target, {VoteType? voteType}) {
    final typeStr = voteType == VoteType.pk ? 'PK投票' : '投票';
    _gameEventController.add('$typeStr: ${voter.name} -> ${target.name}');
  }

  @override
  void onNightResult(List<GamePlayer> deaths, bool isPeacefulNight, int dayNumber) {
    if (isPeacefulNight) {
      _gameEventController.add('昨晚是平安夜');
    } else {
      final deathsStr = deaths.map((p) => p.name).join(', ');
      _gameEventController.add('昨晚死亡: $deathsStr');
    }
  }

  @override
  void onSystemMessage(String message, {int? dayNumber, GamePhase? phase}) {
    var fullMessage = message;
    if (dayNumber != null) {
      fullMessage = '[第${dayNumber}天] $fullMessage';
    }
    if (phase != null) {
      fullMessage = '[${_getPhaseString(phase)}] $fullMessage';
    }
    _gameEventController.add(fullMessage);
  }

  @override
  void onErrorMessage(String error, {Object? errorDetails}) {
    _gameEventController.add('错误: $error');
    _onErrorController.add(error);
  }

  @override
  void onVoteResults(
    Map<String, int> results,
    GamePlayer? executed,
    List<GamePlayer>? pkCandidates,
  ) {
    if (results.isEmpty) {
      _gameEventController.add('没有投票结果');
      return;
    }

    final sortedResults = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var message = '投票结果:\n';
    for (final entry in sortedResults) {
      message += '  ${entry.key}: ${entry.value}票\n';
    }

    if (executed != null) {
      message += '出局: ${executed.name}';
    } else if (pkCandidates != null && pkCandidates.isNotEmpty) {
      message += 'PK候选: ${pkCandidates.map((p) => p.name).join(', ')}';
    }

    _gameEventController.add(message);
  }

  @override
  void onAlivePlayersAnnouncement(List<GamePlayer> alivePlayers) {
    final names = alivePlayers.map((p) => p.name).join(', ');
    _gameEventController.add('当前存活玩家: $names');
  }

  @override
  void onLastWords(GamePlayer player, String lastWords) {
    _gameEventController.add('【遗言】${player.name}: $lastWords');
  }

  @override
  void onGameStateChanged(GameState state) {
    _onGameStateChangedController.add(state);
  }

  // ============ 辅助方法 ============

  String _getPhaseString(GamePhase phase) {
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

  String _getDeathCauseString(DeathCause cause) {
    switch (cause) {
      case DeathCause.werewolfKill:
        return '狼人击杀';
      case DeathCause.vote:
        return '投票出局';
      case DeathCause.poison:
        return '中毒';
      case DeathCause.hunterShot:
        return '猎人射杀';
      case DeathCause.other:
        return '其他原因';
    }
  }

  String _getSpeechTypeString(SpeechType type) {
    switch (type) {
      case SpeechType.normal:
        return '发言';
      case SpeechType.werewolfDiscussion:
        return '狼人讨论';
      case SpeechType.lastWords:
        return '遗言';
    }
  }

  /// 释放资源
  void dispose() {
    _gameEventController.close();
    _onGameStartController.close();
    _onPhaseChangeController.close();
    _onPlayerActionController.close();
    _onGameEndController.close();
    _onErrorController.close();
    _onGameStateChangedController.close();
  }
}
