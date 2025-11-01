// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:werewolf_arena/console/console_game_config_loader.dart';
import 'package:werewolf_arena/console/console_game_observer.dart';
import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/console/console_human_player_driver_input.dart';
import 'package:werewolf_arena/engine/player/aggressive_warrior_persona.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/player/human_player.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/driver/human_player_driver.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_round/default_game_round_controller.dart';
import 'package:werewolf_arena/engine/player/petty_artist_persona.dart';
import 'package:werewolf_arena/engine/player/logic_master_persona.dart';
import 'package:werewolf_arena/engine/player/observant_skeptic_persona.dart';
import 'package:werewolf_arena/engine/player/pragmatic_veteran_persona.dart';
import 'package:werewolf_arena/engine/player/narrator_persona.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';

/// 狼人杀竞技场 - 控制台模式入口
///
/// 基于新架构的控制台应用：
/// - 简化启动流程，移除复杂的参数管理
/// - 保持控制台友好的用户体验
Future<void> main(List<String> arguments) async {
  final ui = ConsoleGameUI.instance;

  try {
    // 解析命令行参数
    final parser = ArgParser()
      ..addOption('config', abbr: 'c', help: '配置文件路径')
      ..addOption('players', abbr: 'p', help: '玩家数量 (9或12)')
      ..addOption('scenario', abbr: 's', help: '游戏场景ID')
      ..addOption('player', help: '指定由真人玩家控制的玩家编号 (1-12)')
      ..addFlag('god', abbr: 'g', help: '启用上帝视角', defaultsTo: false)
      ..addFlag('debug', abbr: 'd', help: '启用调试模式', defaultsTo: false)
      ..addFlag('help', abbr: 'h', help: '显示帮助信息', negatable: false);

    final ArgResults argResults;
    try {
      argResults = parser.parse(arguments);
    } catch (e) {
      print('错误: 无效的命令行参数\n');
      _printHelp(parser);
      exit(1);
    }

    if (argResults['help'] as bool) {
      _printHelp(parser);
      return;
    }

    // 初始化控制台
    ui.initialize(useColors: true);
    ui.startSpinner();

    final playerCountStr = argResults['players'] as String?;

    int? playerCount;
    if (playerCountStr != null) {
      playerCount = int.tryParse(playerCountStr);
      if (playerCount == null || (playerCount != 9 && playerCount != 12)) {
        ui.displayError('无效的玩家数量: $playerCountStr (支持9或12人)');
        exit(1);
      }
    }

    // 解析人类玩家参数
    int? humanPlayerIndex;
    final humanPlayerStr = argResults['player'] as String?;
    if (humanPlayerStr != null) {
      humanPlayerIndex = int.tryParse(humanPlayerStr);
      if (humanPlayerIndex == null ||
          humanPlayerIndex < 1 ||
          humanPlayerIndex > 12) {
        ui.displayError('无效的玩家编号: $humanPlayerStr (支持1-12)');
        exit(1);
      }
    } else {
      // 如果没有指定玩家，随机分配一个
      humanPlayerIndex = Random().nextInt(12) + 1;
    }

    // 创建游戏引擎和玩家
    final gameEngineData = await _createGameEngine(
      ui,
      humanPlayerIndex,
      argResults['debug'] as bool,
      argResults['god'] as bool,
    );
    final gameEngine = gameEngineData['engine'] as GameEngine;
    final humanPlayer = gameEngineData['humanPlayer'] as GamePlayer;

    await gameEngine.ensureInitialized();

    // 显示玩家通知
    ui.pauseSpinner();
    _showPlayerNotification(ui, humanPlayer);

    // 等待用户确认
    print('\n按回车键开始游戏...');
    stdin.readLineSync();
    print('');

    ui.resumeSpinner();

    while (!gameEngine.isGameEnded) {
      await gameEngine.loop();

      // 添加小延迟，让用户有时间阅读输出
      await Future.delayed(const Duration(milliseconds: 500));
    }

    ui.printLine();
    ui.printSeparator('=', 60);
    ui.printLine('✅ 游戏已结束');

    final finalState = gameEngine.currentState;
    if (finalState != null && finalState.winner != null) {
      ui.printLine('🏆 获胜者: ${finalState.winner}');
      ui.printLine('🕐 游戏时长: ${finalState.day} 天');
      ui.printLine('⚰️ 存活玩家: ${finalState.alivePlayers.length}');
    }
    ui.dispose();
    exit(0);
  } catch (e, stackTrace) {
    ui.displayError('运行错误: $e', errorDetails: stackTrace);
    ui.dispose();
    exit(1);
  }
}

Future<Map<String, dynamic>> _createGameEngine(
  ConsoleGameUI ui,
  int? humanPlayerIndex,
  bool showLog,
  bool showGod,
) async {
  final config = await ConsoleGameConfigLoader().loadGameConfig();
  final scenario = Scenario12Players();
  final players = <GamePlayer>[];
  final roles = scenario.roles;
  roles.shuffle();
  final personas = [
    AggressiveWarriorPersona(),
    LogicMasterPersona(),
    NarratorPersona(),
    ObservantSkepticPersona(),
    PettyArtistPersona(),
    PragmaticVeteranPersona(),
  ];

  GamePlayer? humanPlayer;

  for (int i = 0; i < roles.length; i++) {
    final playerIndex = i + 1;
    final role = roles[i];
    final intelligence = config.playerIntelligences[i];

    // 如果当前玩家是人类玩家，创建HumanPlayer
    if (humanPlayerIndex != null && playerIndex == humanPlayerIndex) {
      final player = HumanPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: role,
        driver: HumanPlayerDriver(
          inputReader: ConsoleHumanPlayerDriverInput(ui),
        ),
      );
      players.add(player);
      humanPlayer = player;
    } else {
      // 否则创建AIPlayer
      final random = Random().nextInt(personas.length);
      final player = AIPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: role,
        driver: AIPlayerDriver(
          intelligence: intelligence,
          maxRetries: config.maxRetries,
        ),
        persona: personas[random],
      );
      players.add(player);
    }
  }

  // 创建带人类玩家视角的observer
  final observer = ConsoleGameObserver(
    ui: ui,
    showLog: showLog,
    showRole: showGod,
    humanPlayer: humanPlayer,
  );

  final engine = GameEngine(
    config: config,
    scenario: scenario,
    players: players,
    observer: observer,
    controller: DefaultGameRoundController(),
  );

  return {'engine': engine, 'humanPlayer': humanPlayer};
}

/// 打印帮助信息
void _printHelp(ArgParser parser) {
  print('狼人杀竞技场 - 控制台模式 (新架构)');
  print('');
  print('用法: dart run bin/main.dart [选项]');
  print('');
  print('选项:');
  print(parser.usage);
  print('');
  print('支持的场景:');
  print('  9_players   - 9人标准局');
  print('  12_players  - 12人局');
  print('');
  print('示例:');
  print('  dart run bin/main.dart                        # 使用默认配置运行（随机分配真人玩家）');
  print('  dart run bin/main.dart -p 9                   # 指定9人局');
  print('  dart run bin/main.dart -s 12_players          # 指定12人场景');
  print('  dart run bin/main.dart -c config/my.yaml      # 使用自定义配置');
  print('  dart run bin/main.dart -d                     # 启用调试模式');
  print('  dart run bin/main.dart -p 9 -c config.yaml   # 组合参数');
  print('  dart run bin/main.dart --player 1             # 1号玩家由真人控制');
  print('  dart run bin/main.dart -p 9 --player 3        # 9人局，3号玩家由真人控制');
}

/// 显示玩家通知
void _showPlayerNotification(ConsoleGameUI ui, GamePlayer player) {
  print('');
  print('=' * 80);
  print('');
  print('🎮 欢迎来到狼人杀竞技场！');
  print('');
  print('-' * 80);
  print('');
  print('📋 你的身份信息:');
  print('');
  print('  👤 玩家编号: ${player.name}');
  print('  🎭 角色: ${player.role.name}');
  print('  📖 角色描述: ${player.role.description}');
  print('');
  print('-' * 80);
  print('');
  print('💡 游戏提示:');
  print('  • 仔细阅读每个技能的提示信息');
  print('  • 关注游戏中发生的事件');
  print('  • 根据你的角色身份制定策略');
  print('  • 输入目标时可以使用简化格式（如输入"1"表示"1号玩家"）');
  if (player.role.name.contains('女巫')) {
    print('  • 女巫的解药和毒药可以选择不使用（输入"跳过"或直接回车）');
  }
  print('');
  print('=' * 80);
  print('');
}
