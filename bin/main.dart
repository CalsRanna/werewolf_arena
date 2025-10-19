// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:werewolf_arena/console/console_game_config_loader.dart';
import 'package:werewolf_arena/console/console_game_observer.dart';
import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/processor/night_phase_processor.dart';
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
    ui.printHeader('狼人杀竞技场', color: ConsoleColor.green);

    final playerCountStr = argResults['players'] as String?;

    int? playerCount;
    if (playerCountStr != null) {
      playerCount = int.tryParse(playerCountStr);
      if (playerCount == null || (playerCount != 9 && playerCount != 12)) {
        ui.displayError('无效的玩家数量: $playerCountStr (支持9或12人)');
        exit(1);
      }
    }

    final observer = ConsoleGameObserver();

    final gameEngine = await _createGameEngine(observer);
    await gameEngine.ensureInitialized();

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
      ui.printLine('🕐 游戏时长: ${finalState.dayNumber} 天');
      ui.printLine('⚰️ 存活玩家: ${finalState.alivePlayers.length}');
    }
  } catch (e, stackTrace) {
    ui.displayError('运行错误: $e', errorDetails: stackTrace);
    exit(1);
  }
}

Future<GameEngine> _createGameEngine(GameObserver observer) async {
  final config = await ConsoleGameConfigLoader().loadGameConfig();
  final scenario = Scenario12Players();
  final players = <GamePlayer>[];
  final roles = scenario.roles;
  roles.shuffle();
  for (int i = 0; i < roles.length; i++) {
    final playerIndex = i + 1;
    final role = roles[i];
    final intelligence = config.playerIntelligences[i];
    final player = AIPlayer(
      id: 'player_$playerIndex',
      name: '$playerIndex号玩家',
      index: playerIndex,
      role: role,
      driver: AIPlayerDriver(intelligence: intelligence),
    );
    players.add(player);
  }
  return GameEngine(
    config: config,
    scenario: scenario,
    players: players,
    observer: observer,
    processor: DefaultPhaseProcessor(),
  );
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
  print('  dart run bin/main.dart                        # 使用默认配置运行');
  print('  dart run bin/main.dart -p 9                   # 指定9人局');
  print('  dart run bin/main.dart -s 12_players          # 指定12人场景');
  print('  dart run bin/main.dart -c config/my.yaml      # 使用自定义配置');
  print('  dart run bin/main.dart -d                     # 启用调试模式');
  print('  dart run bin/main.dart -p 9 -c config.yaml   # 组合参数');
}
