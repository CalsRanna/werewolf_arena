import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class GameViewModel {
  // Signals 状态管理
  final Signal<bool> isGameRunning = signal(false);
  final Signal<bool> isExecutingStep = signal(false);
  final Signal<int> currentDay = signal(0);
  final Signal<String> currentPhase = signal('等待开始');
  final Signal<List<GamePlayer>> players = signal([]);
  final Signal<List<String>> eventLog = signal([]);
  final Signal<String> gameStatus = signal('准备就绪');
  final Signal<int> selectedGamePlayerCount = signal(12);
  final Signal<String> selectedScenario = signal('标准场景');

  // SnackBar提示用的StreamController
  final StreamController<String> _snackBarMessageController =
      StreamController.broadcast();
  Stream<String> get snackBarMessages => _snackBarMessageController.stream;

  // 计算属性
  late final formattedTime = computed(() {
    return '第${currentDay.value}天 - ${currentPhase.value}';
  });

  late final aliveGamePlayersCount = computed(() {
    return players.value.where((p) => p.isAlive).length;
  });

  /// 兼容性属性：与aliveGamePlayersCount相同，为了保持UI兼容性
  late final alivePlayersCount = computed(() {
    return players.value.where((p) => p.isAlive).length;
  });

  late final canStartGame = computed(() {
    return !isGameRunning.value && players.value.isNotEmpty;
  });

  StreamSubscription? _gameEventsSubscription;
  StreamSubscription? _onGameStartSubscription;
  StreamSubscription? _onPhaseChangeSubscription;
  StreamSubscription? _onGamePlayerActionSubscription;
  StreamSubscription? _onGameEndSubscription;
  StreamSubscription? _onErrorSubscription;

  /// 初始化状态
  Future<void> initSignals() async {}

  /// 开始游戏
  Future<void> startGame() async {}

  /// 执行下一步
  Future<void> executeNextStep() async {}

  /// 重置游戏
  Future<void> resetGame() async {}

  /// 设置玩家数量
  void setGamePlayerCount(int count) {}

  /// 设置场景
  void setScenario(String scenarioId) async {}

  /// 导航到设置页面
  void navigateSettingsPage(BuildContext context) {
    SettingsRoute().push(context);
  }

  /// 释放资源
  void dispose() {
    _gameEventsSubscription?.cancel();
    _onGameStartSubscription?.cancel();
    _onPhaseChangeSubscription?.cancel();
    _onGamePlayerActionSubscription?.cancel();
    _onGameEndSubscription?.cancel();
    _onErrorSubscription?.cancel();
    _snackBarMessageController.close();

    isGameRunning.dispose();
    isExecutingStep.dispose();
    currentDay.dispose();
    currentPhase.dispose();
    players.dispose();
    eventLog.dispose();
    gameStatus.dispose();
    selectedGamePlayerCount.dispose();
    selectedScenario.dispose();
    // Computed properties are automatically disposed with their dependencies
  }
}
