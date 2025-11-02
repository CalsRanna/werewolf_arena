// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:werewolf_arena/console/console_game_config_loader.dart';
import 'package:werewolf_arena/console/console_game_observer.dart';
import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/console/console_human_player_driver_ui.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/player/human_player.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/round/default_game_round_controller.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';

Future<void> main(List<String> arguments) async {
  final ui = ConsoleGameUI.instance;

  try {
    final parser = ArgParser()
      ..addOption('config', abbr: 'c', help: '配置文件路径')
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

    ui.initialize(useColors: true);
    ui.startSpinner();

    int? humanPlayerIndex;
    final isGodMode = argResults['god'] as bool;

    if (isGodMode) {
      humanPlayerIndex = null;
      if (argResults['player'] != null) {
        ui.displayError('上帝视角模式 (-g) 与人类玩家模式 (--player) 不能同时使用');
        exit(1);
      }
    } else {
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
        humanPlayerIndex = Random().nextInt(12) + 1;
      }
    }

    final gameEngineData = await _createGameEngine(
      ui,
      humanPlayerIndex,
      argResults['debug'] as bool,
      argResults['god'] as bool,
    );
    final gameEngine = gameEngineData['engine'] as GameEngine;
    final humanPlayer = gameEngineData['humanPlayer'] as GamePlayer?;

    final game = await gameEngine.create();

    ui.pauseSpinner();
    if (humanPlayer != null) {
      _showPlayerNotification(ui, humanPlayer);

      print('\n按回车键开始游戏...');
      stdin.readLineSync(encoding: utf8);
      print('');
    } else {
      print('\n上帝视角模式已启用，所有玩家均由 AI 控制');
    }

    ui.resumeSpinner();

    while (!game.isGameEnded) {
      await game.loop();
    }

    final winner = game.winner;
    final day = game.day;
    final players = game.players
        .map((p) => '${p.name} ${p.role.name}')
        .join(', ');
    final alivePlayers = game.alivePlayers
        .map((p) => '${p.name} ${p.role.name}')
        .join(', ');

    ui.printLine();
    ui.printLine('游戏结束');
    ui.printLine('获胜者: $winner');
    ui.printLine('游戏时长: $day 天');
    ui.printLine('玩家身份： $players');
    ui.printLine('存活玩家: $alivePlayers');

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

  GamePlayer? humanPlayer;

  for (int i = 0; i < roles.length; i++) {
    final playerIndex = i + 1;
    final role = roles[i];
    final intelligence = config.playerIntelligences[i];

    if (humanPlayerIndex != null && playerIndex == humanPlayerIndex) {
      final player = HumanPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: role,
        input: ConsoleHumanPlayerDriverUI(ui),
      );
      players.add(player);
      humanPlayer = player;
    } else {
      final player = AIPlayer(
        id: 'player_$playerIndex',
        name: '$playerIndex号玩家',
        index: playerIndex,
        role: role,
        intelligence: intelligence,
        fastModelId: config.fastModelId,
      );
      players.add(player);
    }
  }

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

void _printHelp(ArgParser parser) {
  print('狼人杀竞技场 - 控制台模式 (新架构)');
  print('');
  print('用法: dart run bin/main.dart [选项]');
  print('');
  print('选项:');
  print(parser.usage);
  print('');
  print('玩家模式说明:');
  print('  --player N  - 指定N号玩家由真人控制（1-12）');
  print('  -g, --god   - 上帝视角模式，所有玩家均由AI控制，可观察所有信息');
  print('  注意: -g 和 --player 参数不能同时使用');
  print('');
  print('支持的场景:');
  print('  9_players   - 9人标准局');
  print('  12_players  - 12人局');
  print('');
  print('示例:');
  print('  dart run bin/main.dart                        # 使用默认配置运行（随机分配真人玩家）');
  print('  dart run bin/main.dart -g                     # 上帝视角模式（所有玩家由AI控制）');
  print('  dart run bin/main.dart --player 1             # 1号玩家由真人控制');
  print('  dart run bin/main.dart -c config/my.yaml      # 使用自定义配置');
  print('  dart run bin/main.dart -d                     # 启用调试模式');
  print('  dart run bin/main.dart -g -d                  # 上帝视角+调试模式');
}

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
