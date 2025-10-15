import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/engine/domain/entities/ai_player.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role_factory.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_random.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_12_players.dart';
import 'package:werewolf_arena/util/dialog_util.dart';

class DebugViewModel {
  final url = 'https://openrouter.ai/api/v1';
  final key =
      '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';

  late final GameEngine gameEngine;
  final logs = Signal(<String>[]);
  final controller = ScrollController();
  final running = Signal(false);

  Future<void> startGame() async {
    running.value = true;
    await gameEngine.initializeGame();
    while (!gameEngine.isGameEnded) {
      await gameEngine.executeGameStep();
    }
    running.value = false;
  }

  Future<void> stopGame() async {
    running.value = false;
    gameEngine.dispose();
    logs.value = [];
  }

  Future<void> initSignals() async {
    var intelligence = PlayerIntelligence(
      baseUrl: url,
      apiKey: key,
      modelId: 'deepseek/deepseek-v3.2-exp',
    );
    final config = GameConfig(
      playerIntelligences: [intelligence],
      maxRetries: 3,
    );
    final scenario = Scenario12Players();
    final observer = _Observer((String message) async {
      await DialogUtil.instance.show(message);
      logs.value = [...logs.value, message];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: Durations.short3,
          curve: Curves.linear,
        );
      });
    });
    final players = <GamePlayer>[];
    final random = GameRandom();

    // 获取角色列表并随机分配
    final roleTypes = scenario.getExpandedGameRoles();
    roleTypes.shuffle(random.generator);

    // 创建玩家
    for (int i = 0; i < scenario.playerCount; i++) {
      final playerIndex = i + 1; // 玩家编号从1开始
      final roleType = roleTypes[i];
      final role = GameRoleFactory.createRoleFromType(roleType);

      final intelligence = PlayerIntelligence(
        baseUrl: url,
        apiKey: key,
        modelId: 'deepseek/deepseek-v3.2-exp',
      );

      final player = AIPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: role,
        intelligence: intelligence,
      );

      players.add(player);
    }
    gameEngine = GameEngine(
      config: config,
      scenario: scenario,
      players: players,
      observer: observer,
    );
  }

  void dispose() {
    controller.dispose();
    gameEngine.dispose();
  }
}

class _Observer extends GameObserver {
  final Future<void> Function(String) onLog;

  _Observer(this.onLog);

  @override
  Future<void> onGameEvent(GameEvent event) async {
    await onLog(event.toString());
  }
}
