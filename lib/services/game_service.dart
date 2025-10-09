import 'dart:async';
import 'package:werewolf_arena/core/engine/game_engine.dart';
import 'package:werewolf_arena/core/engine/game_engine_callbacks.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/state/game_event.dart';
import 'package:werewolf_arena/core/entities/player/player.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/shared/random_helper.dart';

/// 游戏服务 - Flutter友好的包装层
class GameService implements GameEventCallbacks {
  bool _isInitialized = false;
  GameEngine? _gameEngine;
  ConfigManager? _configManager;

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

  /// 获取当前游戏状态
  GameState? get currentState => _gameEngine?.currentState;

  /// 游戏是否已结束
  bool get isGameEnded => _gameEngine?.isGameEnded ?? true;

  /// 初始化游戏服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _configManager = ConfigManager.instance;

    // 创建游戏引擎并设置回调
    _gameEngine = GameEngine(
      configManager: _configManager!,
      random: RandomHelper(),
      callbacks: this,
    );

    _isInitialized = true;
    _gameEventController.add('游戏服务已初始化');
  }

  /// 初始化游戏
  Future<void> initializeGame() async {
    _ensureInitialized();
    await _gameEngine!.initializeGame();
    _gameEventController.add('游戏初始化完成');
  }

  /// 设置玩家列表
  void setPlayers(List<Player> players) {
    _ensureInitialized();
    _gameEngine!.setPlayers(players);
    _gameEventController.add('设置玩家列表：${players.length} 个玩家');
  }

  /// 获取当前玩家列表
  List<Player> getCurrentPlayers() {
    _ensureInitialized();
    return _gameEngine!.currentState?.players ?? [];
  }

  /// 开始游戏
  Future<void> startGame() async {
    _ensureInitialized();
    await _gameEngine!.startGame();
    _gameEventController.add('游戏开始');
    _onGameStartController.add(null);
  }

  /// 执行下一步
  Future<void> executeNextStep() async {
    _ensureInitialized();
    await _gameEngine!.executeGameStep();
    _gameEventController.add('执行下一步');
  }

  /// 重置游戏
  Future<void> resetGame() async {
    _ensureInitialized();

    // 清理旧引擎
    _gameEngine?.dispose();

    // 创建新引擎
    _gameEngine = GameEngine(
      configManager: _configManager!,
      random: RandomHelper(),
      callbacks: this,
    );

    _gameEventController.add('游戏重置');
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized || _gameEngine == null) {
      throw StateError('GameService未初始化,请先调用initialize()');
    }
  }

  // ============ GameEventCallbacks 实现 ============

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
    Player player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {
    final targetStr = target is Player ? target.name : target.toString();
    var message = '${player.name} 执行 $actionType -> $targetStr';
    if (details != null && details.isNotEmpty) {
      message +=
          ' (${details.entries.map((e) => '${e.key}: ${e.value}').join(', ')})';
    }
    _gameEventController.add(message);
    _onPlayerActionController.add(message);
  }

  @override
  void onPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
    final causeStr = _getDeathCauseString(cause);
    var message = '${player.name} 死亡 ($causeStr)';
    if (killer != null) {
      message += ' - 凶手: ${killer.name}';
    }
    _gameEventController.add(message);
  }

  @override
  void onPlayerSpeak(Player player, String message, {SpeechType? speechType}) {
    final typeStr = speechType != null
        ? '[${_getSpeechTypeString(speechType)}]'
        : '';
    _gameEventController.add('$typeStr${player.name}: $message');
  }

  @override
  void onVoteCast(Player voter, Player target, {VoteType? voteType}) {
    final typeStr = voteType == VoteType.pk ? 'PK投票' : '投票';
    _gameEventController.add('$typeStr: ${voter.name} -> ${target.name}');
  }

  @override
  void onNightResult(List<Player> deaths, bool isPeacefulNight, int dayNumber) {
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
    Player? executed,
    List<Player>? pkCandidates,
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
  void onAlivePlayersAnnouncement(List<Player> alivePlayers) {
    final names = alivePlayers.map((p) => p.name).join(', ');
    _gameEventController.add('当前存活玩家: $names');
  }

  @override
  void onLastWords(Player player, String lastWords) {
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
    _gameEngine?.dispose();
    _gameEventController.close();
    _onGameStartController.close();
    _onPhaseChangeController.close();
    _onPlayerActionController.close();
    _onGameEndController.close();
    _onErrorController.close();
    _onGameStateChangedController.close();
  }
}
