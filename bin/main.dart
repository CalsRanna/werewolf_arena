// ignore_for_file: avoid_print

import 'dart:io';
import 'package:args/args.dart';
import 'package:werewolf_arena/engine/game_assembler.dart';
import 'package:werewolf_arena/engine/game_engine.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/services/game_log_observer.dart';
import 'console_output.dart';
import 'console_observer.dart';

/// 狼人杀竞技场 - 控制台模式入口
///
/// 基于新架构的控制台应用：
/// - 使用GameAssembler创建游戏引擎
/// - 简化启动流程，移除复杂的参数管理
/// - 保持控制台友好的用户体验
Future<void> main(List<String> arguments) async {
  final console = GameConsole.instance;

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
    console.initialize(useColors: true);
    console.printHeader('狼人杀竞技场 - 控制台模式', color: ConsoleColor.green);

    // 1. 解析启动参数
    console.printLine('⚙️ 解析启动参数...');

    final configPath = argResults['config'] as String?;
    final playerCountStr = argResults['players'] as String?;
    final scenarioId = argResults['scenario'] as String?;

    int? playerCount;
    if (playerCountStr != null) {
      playerCount = int.tryParse(playerCountStr);
      if (playerCount == null || (playerCount != 9 && playerCount != 12)) {
        console.displayError('无效的玩家数量: $playerCountStr (支持9或12人)');
        exit(1);
      }
    }

    // 显示启动配置
    console.printLine('   配置文件: ${configPath ?? '默认配置'}');
    console.printLine('   玩家数量: ${playerCount ?? '默认(9人)'}');
    console.printLine('   游戏场景: ${scenarioId ?? '自动选择'}');
    console.printLine();

    // 2. 创建游戏观察者
    console.printLine('👁️ 创建游戏观察者...');
    final observer = CompositeGameObserver();
    observer.addObserver(ConsoleGameObserver());
    observer.addObserver(GameLogObserver());

    // 3. 使用GameAssembler创建游戏引擎
    console.printLine('🎮 正在组装游戏引擎...');

    GameEngine gameEngine;
    try {
      gameEngine = await GameAssembler.assembleGame(
        configPath: configPath,
        scenarioId: scenarioId,
        playerCount: playerCount,
        observer: observer,
      );
      console.printLine('   ✅ 游戏引擎创建成功');
    } catch (e) {
      console.displayError('游戏引擎创建失败: $e');
      console.printLine();
      console.printLine('💡 建议检查：');
      console.printLine('   - 配置文件是否存在且格式正确');
      console.printLine('   - API密钥是否有效');
      console.printLine('   - 网络连接是否正常');
      exit(1);
    }

    // 4. 显示游戏信息
    console.printLine();
    console.printSeparator('=', 60);
    console.printLine();
    console.printLine('🎯 游戏信息：');
    console.printLine('   场景: ${gameEngine.scenario.name}');
    console.printLine('   描述: ${gameEngine.scenario.description}');
    console.printLine('   玩家数量: ${gameEngine.players.length}');
    console.printLine();

    // 显示玩家列表
    console.printLine('👥 玩家列表：');
    for (var i = 0; i < gameEngine.players.length; i++) {
      final player = gameEngine.players[i];
      console.printLine('   ${i + 1}. ${player.name} (${player.role.name})');
    }

    console.printLine();
    console.printSeparator('=', 60);
    console.printLine();

    // 5. 初始化游戏引擎
    console.printLine('🔧 初始化游戏引擎...');
    try {
      await gameEngine.initializeGame();
      console.printLine('   ✅ 游戏引擎初始化成功');
    } catch (e) {
      console.displayError('游戏引擎初始化失败: $e');
      exit(1);
    }

    // 6. 开始游戏循环
    console.printLine('🚀 开始游戏...\n');

    // 现在开始执行游戏步骤
    while (!gameEngine.isGameEnded) {
      try {
        await gameEngine.executeGameStep();

        // 添加小延迟，让用户有时间阅读输出
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        console.displayError('游戏执行错误: $e');
        console.printLine('尝试继续游戏...\n');
      }
    }

    // 7. 游戏结束
    console.printLine();
    console.printSeparator('=', 60);
    console.printLine('✅ 游戏已结束');

    final finalState = gameEngine.currentState;
    if (finalState != null && finalState.winner != null) {
      console.printLine('🏆 获胜者: ${finalState.winner}');
      console.printLine('🕐 游戏时长: ${finalState.dayNumber} 天');
      console.printLine('⚰️ 存活玩家: ${finalState.alivePlayers.length}');
    }
  } catch (e, stackTrace) {
    console.displayError('运行错误: $e', errorDetails: stackTrace);
    exit(1);
  }
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
