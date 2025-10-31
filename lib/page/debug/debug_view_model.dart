import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/event/announce_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_round/default_game_round_controller.dart';
import 'package:werewolf_arena/engine/player/aggressive_warrior_persona.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/disciple_persona.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/player/inquisitor_persona.dart';
import 'package:werewolf_arena/engine/player/logic_master_persona.dart';
import 'package:werewolf_arena/engine/player/lurker_persona.dart';
import 'package:werewolf_arena/engine/player/peacemaker_persona.dart';
import 'package:werewolf_arena/engine/player/refined_egoist_persona.dart';
import 'package:werewolf_arena/engine/player/schemer_persona.dart';
import 'package:werewolf_arena/engine/player/thespian_persona.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';
import 'package:werewolf_arena/page/player_intelligence/player_intelligence_view_model.dart';
import 'package:werewolf_arena/router/router.gr.dart';
import 'package:werewolf_arena/util/logger_util.dart';

class DebugViewModel {
  late final GameEngine gameEngine;
  final logs = Signal(<String>[]);
  final running = Signal(false);

  void dispose() {
    gameEngine.dispose();
  }

  Future<void> initSignals() async {
    final intelligence = await _getPlayerIntelligence();
    final config = GameConfig(
      playerIntelligences: [intelligence],
      maxRetries: 10,
    );
    final scenario = Scenario12Players();
    final roles = scenario.roles;
    roles.shuffle();
    final personas = [
      AggressiveWarriorPersona(),
      DisciplePersona(),
      InquisitorPersona(),
      LogicMasterPersona(),
      LurkerPersona(),
      PeacemakerPersona(),
      RefinedEgoistPersona(),
      SchemerPersona(),
      ThespianPersona(),
    ];
    personas.shuffle();
    final players = <GamePlayer>[];
    for (int i = 0; i < roles.length; i++) {
      final playerIndex = i + 1; // 玩家编号从1开始
      var driver = AIPlayerDriver(
        intelligence: intelligence,
        maxRetries: config.maxRetries,
      );
      final player = AIPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: roles[i],
        driver: driver,
        persona: personas[i % personas.length],
      );
      players.add(player);
    }
    final observer = _Observer(handleGameEvent: _handleGameEvent);
    gameEngine = GameEngine(
      config: config,
      scenario: scenario,
      players: players,
      observer: observer,
      controller: DefaultGameRoundController(),
    );
  }

  void navigateSettingsPage(BuildContext context) {
    SettingsRoute().push(context);
  }

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
    gameEngine.endGame();
    logs.value = [];
  }

  Future<PlayerIntelligence> _getPlayerIntelligence() async {
    final viewModel = GetIt.instance.get<PlayerIntelligenceViewModel>();
    await viewModel.initSignals();

    // 使用第一个可用模型，如果没有则使用默认值
    final modelId = viewModel.llmModels.value.isNotEmpty
        ? viewModel.llmModels.value.first
        : 'minimax/minimax-m2:free';

    var intelligence = PlayerIntelligence(
      baseUrl: viewModel.defaultBaseUrl.value,
      apiKey: viewModel.defaultApiKey.value,
      modelId: modelId,
    );
    return intelligence;
  }

  Future<void> _handleGameEvent(GameEvent event) async {
    if (event is LogEvent) {
      LoggerUtil.instance.d(event.toNarrative());
      return;
    }
    var message = switch (event) {
      AnnounceEvent() => event.announcement,
      ConspireEvent() => event.message,
      DiscussEvent() => event.message,
      _ => event.toString(),
    };
    logs.value = [...logs.value, message];
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
