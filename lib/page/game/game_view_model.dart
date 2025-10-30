import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/player/aggressive_warrior_persona.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_round/default_game_round_controller.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';
import 'package:werewolf_arena/router/router.gr.dart';
import 'package:werewolf_arena/util/logger_util.dart';

class GameViewModel {
  // 场景ID
  String? scenarioId;

  // 游戏引擎
  GameEngine? _gameEngine;

  // 事件弹窗回调
  Function(String message)? onShowEventDialog;

  // Signals 状态管理
  final Signal<bool> isGameRunning = signal(false);
  final Signal<List<GamePlayer>> players = signal([]);
  final Signal<List<String>> eventLog = signal([]);
  final Signal<String> gameStatus = signal('准备就绪');
  final Signal<int> currentDay = signal(0);

  // SnackBar提示用的StreamController
  final StreamController<String> _snackBarMessageController =
      StreamController.broadcast();
  Stream<String> get snackBarMessages => _snackBarMessageController.stream;

  // 计算属性
  late final formattedTime = computed(() {
    return '第${currentDay.value}天}';
  });

  late final alivePlayersCount = computed(() {
    return players.value.where((p) => p.isAlive).length;
  });

  late final canStartGame = computed(() {
    return !isGameRunning.value && scenarioId != null;
  });

  /// 初始化状态
  Future<void> initSignals({String? scenarioId}) async {
    this.scenarioId = scenarioId;
    if (scenarioId != null) {
      final scenario = _getScenarioById(scenarioId);
      if (scenario != null) {
        gameStatus.value = '准备开始 ${scenario.name}';
      }
    }
  }

  /// 根据ID获取场景
  dynamic _getScenarioById(String id) {
    // 简单直接：只支持12人局
    if (id == 'standard_12_players') {
      return Scenario12Players();
    }
    return null;
  }

  /// 开始游戏
  Future<void> startGame() async {
    if (scenarioId == null) {
      _snackBarMessageController.add('未选择游戏场景');
      return;
    }

    final scenario = _getScenarioById(scenarioId!);
    if (scenario == null) {
      _snackBarMessageController.add('场景不存在');
      return;
    }

    isGameRunning.value = true;
    gameStatus.value = '游戏进行中';

    try {
      // 创建游戏配置（使用硬编码的API配置，实际应该从ConfigService获取）
      final intelligence = PlayerIntelligence(
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey:
            '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',
        modelId: 'deepseek/deepseek-v3.2-exp',
      );

      final config = GameConfig(
        playerIntelligences: [intelligence],
        maxRetries: 10,
      );

      // 创建观察者
      final observer = _GameObserver(
        handleGameEvent: (event) async {
          if (event is LogEvent) {
            LoggerUtil.instance.d(event.message);
            return;
          }

          var message = switch (event) {
            ConspireEvent() => event.message,
            DiscussEvent() => event.message,
            _ => event.toString(),
          };

          // 添加到事件日志
          eventLog.value = [...eventLog.value, message];

          // 弹窗显示事件
          if (onShowEventDialog != null) {
            onShowEventDialog!(message);
          }
        },
      );

      // 创建玩家
      final gamePlayers = <GamePlayer>[];
      final roles = scenario.roles;
      roles.shuffle();

      for (int i = 0; i < roles.length; i++) {
        final playerIndex = i + 1;
        final player = AIPlayer(
          id: 'player_$playerIndex',
          name: '$playerIndex号玩家',
          index: playerIndex,
          role: roles[i],
          driver: AIPlayerDriver(
            intelligence: intelligence,
            maxRetries: config.maxRetries,
          ),
          persona: AggressiveWarriorPersona(),
        );
        gamePlayers.add(player);
      }

      players.value = gamePlayers;

      // 创建游戏引擎
      _gameEngine = GameEngine(
        config: config,
        scenario: scenario,
        players: gamePlayers,
        observer: observer,
        controller: DefaultGameRoundController(),
      );

      // 初始化并启动游戏循环
      await _gameEngine!.ensureInitialized();

      // 在后台运行游戏循环
      _runGameLoop();
    } catch (e) {
      isGameRunning.value = false;
      gameStatus.value = '启动失败';
      _snackBarMessageController.add('游戏启动失败: $e');
      LoggerUtil.instance.e('游戏启动失败: $e');
    }
  }

  /// 运行游戏循环
  Future<void> _runGameLoop() async {
    try {
      while (_gameEngine != null && !_gameEngine!.isGameEnded) {
        await _gameEngine!.loop();

        // 更新状态（这里需要从游戏引擎获取当前状态）
        // 由于GameEngine没有直接暴露state，我们通过玩家列表更新
        players.value = List.from(players.value);
      }

      // 游戏结束
      isGameRunning.value = false;
      gameStatus.value = '游戏结束';
      _snackBarMessageController.add('游戏结束');
    } catch (e) {
      isGameRunning.value = false;
      gameStatus.value = '游戏异常';
      _snackBarMessageController.add('游戏运行错误: $e');
      LoggerUtil.instance.e('游戏运行错误: $e');
    }
  }

  /// 导航到设置页面
  void navigateSettingsPage(BuildContext context) {
    SettingsRoute().push(context);
  }

  /// 释放资源
  void dispose() {
    _gameEngine?.dispose();
    _snackBarMessageController.close();
  }
}

class _GameObserver extends GameObserver {
  final Future<void> Function(GameEvent)? handleGameEvent;

  _GameObserver({this.handleGameEvent});

  @override
  Future<void> onGameEvent(GameEvent event) async {
    await handleGameEvent?.call(event);
  }
}
