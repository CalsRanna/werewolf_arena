import 'dart:io';
import 'package:args/args.dart';
import 'package:werewolf_arena/core/engine/game_engine.dart';
import 'package:werewolf_arena/services/config_service.dart';
import 'console_output.dart';
import 'console_observer.dart';

/// 狼人杀竞技场 - 控制台模式入口
Future<void> main(List<String> arguments) async {
  final console = GameConsole.instance;

  try {
    // 解析命令行参数
    final parser = ArgParser()
      ..addOption('config', abbr: 'c', help: '配置文件路径')
      ..addOption('players', abbr: 'p', help: '玩家数量')
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

    // 1. 加载配置
    console.printLine('📝 正在加载配置...');
    final configService = ConfigService();

    final configPath = argResults['config'] as String?;
    if (configPath != null) {
      console.printLine('   使用自定义配置: $configPath');
      // 使用自定义配置目录（从配置文件路径提取目录）
      final configDir = configPath.contains('/')
          ? configPath.substring(0, configPath.lastIndexOf('/'))
          : null;
      await configService.ensureInitialized(
        customConfigDir: configDir,
        forceConsoleMode: true,
      );
    } else {
      console.printLine('   从二进制所在目录加载配置');
      await configService.ensureInitialized(forceConsoleMode: true);
    }

    // 2. 初始化游戏引擎
    console.printLine('🎮 正在初始化游戏引擎...');
    final observer = ConsoleGameObserver();
    final gameEngine = GameEngine(
      configManager: configService.configManager!,
      observer: observer,
    );

    // 3. 创建玩家
    console.printLine('👥 正在创建AI玩家...');
    final playerCountStr = argResults['players'] as String?;

    // 选择合适的场景
    if (playerCountStr != null) {
      final playerCount = int.tryParse(playerCountStr);
      if (playerCount == null) {
        console.displayError('无效的玩家数量: $playerCountStr');
        exit(1);
      }
      await configService.autoSelectScenario(playerCount);
    }

    // 使用当前场景创建玩家
    final scenario = configService.currentScenario;
    if (scenario == null) {
      console.displayError('无法获取游戏场景');
      exit(1);
    }

    final players = configService.createPlayersForScenario(scenario);
    console.printLine('   创建了 ${players.length} 个玩家');

    // 设置玩家到游戏引擎
    await gameEngine.initializeGame();
    gameEngine.setPlayers(players);

    console.printLine();
    console.printSeparator('=', 60);
    console.printLine();

    // 4. 开始游戏循环
    console.printLine('🚀 开始游戏...\n');
    await gameEngine.startGame();

    // 执行游戏循环,直到游戏结束
    while (!gameEngine.isGameEnded) {
      await gameEngine.executeGameStep();
    }

    // 5. 游戏结束
    console.printLine();
    console.printSeparator('=', 60);
    console.printLine('✅ 游戏已结束');

  } catch (e, stackTrace) {
    console.displayError('运行错误: $e', errorDetails: stackTrace);
    exit(1);
  }
}

/// 打印帮助信息
void _printHelp(ArgParser parser) {
  print('狼人杀竞技场 - 控制台模式');
  print('');
  print('用法: dart run [选项]');
  print('');
  print('选项:');
  print(parser.usage);
  print('');
  print('示例:');
  print('  dart run                    # 使用默认配置运行');
  print('  dart run -- -p 8            # 指定8个玩家');
  print('  dart run -- -c config.yaml  # 使用自定义配置');
  print('  dart run -- -d              # 启用调试模式');
}
