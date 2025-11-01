import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_round/default_game_round_controller.dart';
import 'package:werewolf_arena/engine/player/aggressive_warrior_persona.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/pragmatic_veteran_persona.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/player/petty_artist_persona.dart';
import 'package:werewolf_arena/engine/player/logic_master_persona.dart';
import 'package:werewolf_arena/engine/player/observant_skeptic_persona.dart';
import 'package:werewolf_arena/engine/player/peacemaker_persona.dart';
import 'package:werewolf_arena/engine/player/refined_egoist_persona.dart';
import 'package:werewolf_arena/engine/player/narrator_persona.dart';
import 'package:werewolf_arena/engine/player/thespian_persona.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';
import 'package:werewolf_arena/page/player_intelligence/player_intelligence_view_model.dart';
import 'package:werewolf_arena/router/router.gr.dart';
import 'package:werewolf_arena/util/logger_util.dart';

class DebugViewModel {
  late final GameEngine gameEngine;
  final logs = Signal(<GameEvent>[]);
  final running = Signal(false);

  final controller = ScrollController();

  void dispose() {
    controller.dispose();
    gameEngine.dispose();
  }

  Future<void> initSignals() async {
    final intelligences = await _getPlayerIntelligences();
    final config = GameConfig(
      maxRetries: 10,
      playerIntelligences: intelligences,
    );
    final scenario = Scenario12Players();
    final roles = scenario.roles;
    roles.shuffle();
    final personas = [
      AggressiveWarriorPersona(),
      PragmaticVeteranPersona(),
      PettyArtistPersona(),
      LogicMasterPersona(),
      ObservantSkepticPersona(),
      PeacemakerPersona(),
      RefinedEgoistPersona(),
      NarratorPersona(),
      ThespianPersona(),
    ];
    personas.shuffle();
    final players = <GamePlayer>[];
    for (int i = 0; i < roles.length; i++) {
      final playerIndex = i + 1; // 玩家编号从1开始
      var driver = AIPlayerDriver(
        intelligence: intelligences[i % intelligences.length],
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

  Future<List<PlayerIntelligence>> _getPlayerIntelligences() async {
    final viewModel = GetIt.instance.get<PlayerIntelligenceViewModel>();
    await viewModel.initSignals();

    final intelligences = [
      viewModel.defaultPlayerIntelligence.value,
      ...viewModel.playerIntelligences.value,
    ];
    return intelligences.map((intelligence) {
      return PlayerIntelligence(
        baseUrl: intelligence.baseUrl.isEmpty
            ? viewModel.defaultBaseUrl.value
            : intelligence.baseUrl,
        apiKey: intelligence.apiKey.isEmpty
            ? viewModel.defaultApiKey.value
            : intelligence.apiKey,
        modelId: intelligence.modelId,
      );
    }).toList();
  }

  Future<void> _handleGameEvent(GameEvent event) async {
    if (event is LogEvent) {
      LoggerUtil.instance.d(event.toNarrative());
      return;
    }
    logs.value = [...logs.value, event];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
