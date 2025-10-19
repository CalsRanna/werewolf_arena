import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/game_log_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';
import 'package:werewolf_arena/util/dialog_util.dart';
import 'package:werewolf_arena/util/logger_util.dart';

class DebugViewModel {
  final url = 'https://openrouter.ai/api/v1';
  final key =
      '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';

  late final GameEngine gameEngine;
  final logs = Signal(<String>[]);
  final running = Signal(false);

  Future<void> startGame() async {
    running.value = true;
    await gameEngine.ensureInitialized();
    while (!gameEngine.isGameEnded) {
      await gameEngine.loop();
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
    final observer = _Observer(
      handleGameEvent: (GameEvent event) async {
        if (event is GameLogEvent) {
          LoggerUtil.instance.d(event.message);
          return;
        }
        var message = switch (event) {
          ConspireEvent() => event.message,
          DiscussEvent() => event.message,
          _ => event.toString(),
        };
        await DialogUtil.instance.show(message);
        logs.value = [...logs.value, message];
      },
    );
    final players = <GamePlayer>[];

    // 获取角色列表并随机分配
    final roles = scenario.roles;
    roles.shuffle();

    // 创建玩家
    for (int i = 0; i < roles.length; i++) {
      final playerIndex = i + 1; // 玩家编号从1开始

      final player = AIPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: roles[i],
        driver: AIPlayerDriver(intelligence: intelligence),
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
    gameEngine.dispose();
  }
}

class _Observer extends GameObserver {
  final Future<void> Function(GameEvent)? handleGameEvent;

  _Observer({this.handleGameEvent});

  @override
  Future<void> onGameEvent(GameEvent event) async {
    await handleGameEvent?.call(event);
  }
}
