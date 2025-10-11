import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/services/game_service.dart';
import 'package:werewolf_arena/services/config_service.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class GameViewModel {
  final GameService _gameService = GetIt.instance.get<GameService>();
  final ConfigService _configService = GetIt.instance.get<ConfigService>();

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

  late final canNextStep = computed(() {
    return isGameRunning.value &&
        !_gameService.isGameEnded &&
        !isExecutingStep.value;
  });

  StreamSubscription? _gameEventsSubscription;
  StreamSubscription? _onGameStartSubscription;
  StreamSubscription? _onPhaseChangeSubscription;
  StreamSubscription? _onGamePlayerActionSubscription;
  StreamSubscription? _onGameEndSubscription;
  StreamSubscription? _onErrorSubscription;

  /// 初始化状态
  Future<void> initSignals() async {
    await _gameService.initialize();
    _setupGameEventListeners();

    // 设置默认游戏配置
    eventLog.value = [];
    gameStatus.value = '准备就绪';

    // 添加初始日志
    _addLog('游戏引擎初始化完成');

    // 自动创建玩家
    try {
      final scenario = _configService.currentScenario;
      if (scenario != null) {
        final newGamePlayers = _configService
            .createGamePlayersForScenario(scenario)
            .cast<GamePlayer>();
        players.value = newGamePlayers;
        _addLog('已创建 ${newGamePlayers.length} 名玩家');
        _addLog('玩家列表: ${newGamePlayers.map((p) => p.formattedName).join(', ')}');
      } else {
        players.value = [];
        _addLog('警告: 未选择游戏场景，无法创建玩家');
      }
    } catch (e) {
      players.value = [];
      _addLog('创建玩家失败: $e');
    }
  }

  /// 开始游戏
  Future<void> startGame() async {
    if (!canStartGame.value) return;

    try {
      gameStatus.value = '正在初始化游戏...';
      _addLog('开始新游戏');

      // 初始化游戏
      await _gameService.initializeGame();

      // 使用已创建的玩家
      if (players.value.isEmpty) {
        throw Exception('玩家列表为空，请先选择游戏场景');
      }

      _gameService.setGamePlayers(players.value);
      _addLog('设置玩家列表: ${players.value.length} 名玩家');

      // 开始游戏
      await _gameService.startGame();
      isGameRunning.value = true;
      gameStatus.value = '等待下一步（点击"下一步"按钮推进游戏）';

      _addLog('游戏已启动，使用手动模式');
    } catch (e) {
      gameStatus.value = '错误: $e';
      _addLog('❌ 游戏启动失败: $e');
      _showSnackBar('游戏启动失败: $e');
    }
  }

  /// 执行下一步
  Future<void> executeNextStep() async {
    if (!canNextStep.value) return;

    try {
      isExecutingStep.value = true;
      gameStatus.value = '正在执行下一步...';

      // 执行游戏的下一步
      await _gameService.executeNextStep();

      // 更新玩家状态
      final currentGamePlayers = _gameService.getCurrentGamePlayers().cast<GamePlayer>();
      players.value = currentGamePlayers;

      // 更新天数
      final currentState = _gameService.currentState;
      if (currentState != null) {
        currentDay.value = currentState.dayNumber;
      }

      // 检查游戏是否结束
      if (_gameService.isGameEnded) {
        gameStatus.value = '游戏已结束';
      } else {
        gameStatus.value = '等待下一步（点击"下一步"推进到下一个阶段）';
      }
    } catch (e) {
      gameStatus.value = '错误: $e';
      _addLog('❌ 执行步骤失败: $e');
      _showSnackBar('执行步骤失败: $e');
    } finally {
      isExecutingStep.value = false;
    }
  }

  /// 重置游戏
  Future<void> resetGame() async {
    isGameRunning.value = false;
    isExecutingStep.value = false;
    currentDay.value = 0;
    currentPhase.value = '等待开始';
    eventLog.value = [];
    gameStatus.value = '准备就绪';

    await _gameService.resetGame();

    // 重新创建玩家
    try {
      final scenario = _configService.currentScenario;
      if (scenario != null) {
        final newGamePlayers = _configService
            .createGamePlayersForScenario(scenario)
            .cast<GamePlayer>();
        players.value = newGamePlayers;
        _addLog('游戏重置 - 重新创建了 ${newGamePlayers.length} 名玩家');
      } else {
        players.value = [];
        _addLog('游戏重置 - 警告: 未选择游戏场景');
      }
    } catch (e) {
      players.value = [];
      _addLog('❌ 游戏重置失败: $e');
      _showSnackBar('游戏重置失败: $e');
    }
  }

  /// 设置玩家数量
  void setGamePlayerCount(int count) {
    selectedGamePlayerCount.value = count;
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
    // 监听主要的游戏事件流 - 这是所有游戏事件的主要来源
    _gameEventsSubscription = _gameService.gameEvents.listen((event) {
      _addLog(event);
    });

    _onGameStartSubscription = _gameService.gameStartStream.listen((_) {
      currentDay.value = 1;
      currentPhase.value = '白天';
      gameStatus.value = '游戏开始';
    });

    _onPhaseChangeSubscription = _gameService.phaseChangeStream.listen((phase) {
      currentPhase.value = phase;
    });

    _onGamePlayerActionSubscription = _gameService.playerActionStream.listen((
      action,
    ) {
      // 玩家动作已经通过 gameEvents 流记录，这里不需要重复添加
    });

    _onGameEndSubscription = _gameService.gameEndStream.listen((result) {
      isGameRunning.value = false;
      gameStatus.value = '游戏结束: $result';
    });

    _onErrorSubscription = _gameService.errorStream.listen((error) {
      gameStatus.value = '错误: $error';
      _addLog('❌ 错误: $error');
      _showSnackBar('错误: $error');
    });
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

  /// 显示SnackBar提示
  void _showSnackBar(String message) {
    _snackBarMessageController.add(message);
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
