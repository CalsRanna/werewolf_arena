import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/services/game_service.dart';
import 'package:werewolf_arena/services/config_service.dart';
import 'package:werewolf_arena/core/entities/player/player.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class GameViewModel {
  final GameService _gameService = GetIt.instance.get<GameService>();
  final ConfigService _configService = GetIt.instance.get<ConfigService>();

  // Signals 状态管理
  final Signal<bool> isGameRunning = signal(false);
  final Signal<int> currentDay = signal(0);
  final Signal<String> currentPhase = signal('等待开始');
  final Signal<List<Player>> players = signal([]);
  final Signal<List<String>> eventLog = signal([]);
  final Signal<String> gameStatus = signal('准备就绪');
  final Signal<bool> isPaused = signal(false);
  final Signal<double> gameSpeed = signal(1.0);
  final Signal<int> selectedPlayerCount = signal(12);
  final Signal<String> selectedScenario = signal('标准场景');

  // 计算属性
  late final formattedTime = computed(() {
    return '第${currentDay.value}天 - ${currentPhase.value}';
  });

  late final alivePlayersCount = computed(() {
    return players.value.where((p) => p.isAlive).length;
  });

  late final canStartGame = computed(() {
    return !isGameRunning.value && players.value.isNotEmpty;
  });

  late final canPauseGame = computed(() {
    return isGameRunning.value && !isPaused.value;
  });

  late final canResumeGame = computed(() {
    return isGameRunning.value && isPaused.value;
  });

  StreamSubscription? _gameEventsSubscription;
  StreamSubscription? _onGameStartSubscription;
  StreamSubscription? _onPhaseChangeSubscription;
  StreamSubscription? _onPlayerActionSubscription;
  StreamSubscription? _onGameEndSubscription;
  StreamSubscription? _onErrorSubscription;

  /// 初始化状态
  Future<void> initSignals() async {
    await _gameService.initialize();
    _setupGameEventListeners();

    // 设置默认游戏配置
    players.value = [];
    eventLog.value = [];
    gameStatus.value = '准备就绪';

    // 添加初始日志
    _addLog('游戏引擎初始化完成');
  }

  /// 开始游戏
  Future<void> startGame() async {
    if (!canStartGame.value) return;

    try {
      gameStatus.value = '正在初始化游戏...';
      _addLog('开始新游戏');

      // 初始化游戏
      await _gameService.initializeGame();

      // 创建玩家
      final scenario = _configService.currentScenario;
      if (scenario == null) {
        throw Exception('未选择游戏场景');
      }

      final newPlayers = _configService.createPlayersForScenario(scenario).cast<Player>();
      _gameService.setPlayers(newPlayers);
      players.value = newPlayers;

      _addLog('创建了 ${newPlayers.length} 名玩家');
      _addLog('玩家列表: ${newPlayers.map((p) => p.formattedName).join(', ')}');

      // 开始游戏
      await _gameService.startGame();
      isGameRunning.value = true;
      gameStatus.value = '游戏进行中';

      _startGameLoop();

    } catch (e) {
      gameStatus.value = '错误: $e';
      _addLog('游戏启动失败: $e');
    }
  }

  /// 暂停游戏
  void pauseGame() {
    if (!canPauseGame.value) return;

    isPaused.value = true;
    gameStatus.value = '游戏已暂停';
    _addLog('游戏暂停');
  }

  /// 恢复游戏
  void resumeGame() {
    if (!canResumeGame.value) return;

    isPaused.value = false;
    gameStatus.value = '游戏进行中';
    _addLog('游戏恢复');
  }

  /// 重置游戏
  Future<void> resetGame() async {
    isGameRunning.value = false;
    isPaused.value = false;
    currentDay.value = 0;
    currentPhase.value = '等待开始';
    eventLog.value = [];
    gameStatus.value = '准备就绪';

    await _gameService.resetGame();
    players.value = [];

    _addLog('游戏重置');
  }

  /// 设置游戏速度
  void setGameSpeed(double speed) {
    gameSpeed.value = speed;
    _addLog('游戏速度设置为 ${speed.toStringAsFixed(1)}x');
  }

  /// 设置玩家数量
  void setPlayerCount(int count) {
    selectedPlayerCount.value = count;
    _addLog('选择玩家数量: $count');

    // 自动选择合适的场景
    _configService.autoSelectScenario(count);
  }

  /// 设置场景
  void setScenario(String scenarioId) async {
    await _configService.setScenario(scenarioId);
    selectedScenario.value = _configService.currentScenarioName;
    _addLog('选择场景: ${selectedScenario.value}');
  }

  /// 导航到设置页面
  void navigateSettingsPage(BuildContext context) {
    SettingsRoute().push(context);
  }

  /// 设置游戏事件监听器
  void _setupGameEventListeners() {
    _onGameStartSubscription = _gameService.gameStartStream.listen((_) {
      currentDay.value = 1;
      currentPhase.value = '白天';
      gameStatus.value = '游戏开始';
      _addLog('🎮 游戏正式开始！');
    });

    _onPhaseChangeSubscription = _gameService.phaseChangeStream.listen((phase) {
      currentPhase.value = phase;
      _addLog('🔄 阶段切换: $phase');
    });

    _onPlayerActionSubscription = _gameService.playerActionStream.listen((action) {
      _addLog('👤 $action');
    });

    _onGameEndSubscription = _gameService.gameEndStream.listen((result) {
      isGameRunning.value = false;
      gameStatus.value = '游戏结束: $result';
      _addLog('🏆 游戏结束! 获胜方: $result');
    });

    _onErrorSubscription = _gameService.errorStream.listen((error) {
      gameStatus.value = '错误: $error';
      _addLog('❌ 错误: $error');
    });
  }

  /// 游戏循环
  Future<void> _startGameLoop() async {
    while (isGameRunning.value && !_gameService.isGameEnded) {
      if (!isPaused.value) {
        await _gameService.executeNextStep();

        // 更新玩家状态
        final currentPlayers = _gameService.getCurrentPlayers().cast<Player>();
        players.value = currentPlayers;

        // 更新天数
        final currentState = _gameService.currentState;
        if (currentState != null) {
          currentDay.value = currentState.dayNumber;
        }

        // 根据游戏速度调整延迟
        final delay = Duration(milliseconds: (1000 / gameSpeed.value).round());
        await Future.delayed(delay);
      } else {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
  }

  /// 添加日志
  void _addLog(String message) {
    final now = DateTime.now().toString().substring(11, 19);
    eventLog.value = [...eventLog.value, '[$now] $message'];

    // 保持日志数量在合理范围内
    if (eventLog.value.length > 100) {
      eventLog.value = eventLog.value.sublist(eventLog.value.length - 100);
    }
  }

  /// 释放资源
  void dispose() {
    _gameEventsSubscription?.cancel();
    _onGameStartSubscription?.cancel();
    _onPhaseChangeSubscription?.cancel();
    _onPlayerActionSubscription?.cancel();
    _onGameEndSubscription?.cancel();
    _onErrorSubscription?.cancel();

    isGameRunning.dispose();
    currentDay.dispose();
    currentPhase.dispose();
    players.dispose();
    eventLog.dispose();
    gameStatus.dispose();
    isPaused.dispose();
    gameSpeed.dispose();
    selectedPlayerCount.dispose();
    selectedScenario.dispose();
    // Computed properties are automatically disposed with their dependencies
  }
}