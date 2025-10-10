import 'dart:io';
import 'package:args/args.dart';
import 'package:werewolf_arena/core/domain/value_objects/player_model_config.dart';
import 'package:werewolf_arena/core/engine/game_engine.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/core/scenarios/scenario_registry.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/domain/entities/ai_player.dart';
import 'package:werewolf_arena/services/llm/llm_service.dart';
import 'package:werewolf_arena/services/llm/prompt_manager.dart';
import 'console_output.dart';
import 'console_observer.dart';
import 'console_config.dart';
import 'config_loader.dart';
import 'console_game_parameters.dart';

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

    // 0. 配置文件自检
    console.printLine('🔍 检查配置文件...');
    final configHelper = ConsoleConfigHelper();
    final configDir = await configHelper.ensureConfigFiles();

    if (configDir == null) {
      console.displayError('配置文件初始化失败，程序退出');
      exit(1);
    }

    // 1. 加载配置
    console.printLine('📝 正在加载配置...');

    AppConfig appConfig;
    String? configDirPath;
    final configPath = argResults['config'] as String?;

    if (configPath != null) {
      console.printLine('   使用自定义配置: $configPath');
      // 使用自定义配置目录（从配置文件路径提取目录）
      configDirPath = configPath.contains('/')
          ? configPath.substring(0, configPath.lastIndexOf('/'))
          : null;
      final loader = ConsoleConfigLoader(customConfigDir: configDirPath);
      appConfig = await loader.loadConfig();
    } else {
      console.printLine('   从可执行文件目录加载配置: $configDir');
      final loader = ConsoleConfigLoader(customConfigDir: configDir);
      appConfig = await loader.loadConfig();
    }

    // 初始化场景管理器
    final scenarioRegistry = ScenarioRegistry();
    scenarioRegistry.initialize();

    // 2. 初始化游戏引擎
    console.printLine('🎮 正在初始化游戏引擎...');
    final observer = ConsoleGameObserver();

    // 创建控制台游戏参数
    final gameParameters = ConsoleGameParameters(appConfig, scenarioRegistry);

    final gameEngine = GameEngine(
      parameters: gameParameters,
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
      final scenarios = scenarioRegistry.getScenariosByPlayerCount(playerCount);
      if (scenarios.isEmpty) {
        console.displayError('没有找到适合 $playerCount 人的场景');
        exit(1);
      }
      gameParameters.setCurrentScenario(scenarios.first.id);
    } else {
      // 使用默认场景
      final allScenarios = scenarioRegistry.scenarios.values.toList();
      if (allScenarios.isEmpty) {
        console.displayError('没有可用的游戏场景');
        exit(1);
      }
      gameParameters.setCurrentScenario(allScenarios.first.id);
    }

    // 使用当前场景创建玩家
    final scenario = gameParameters.currentScenario;
    if (scenario == null) {
      console.displayError('无法获取游戏场景');
      exit(1);
    }

    final players = _createPlayersForScenario(scenario, appConfig);
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

/// 为场景创建玩家
List<Player> _createPlayersForScenario(
  GameScenario scenario,
  AppConfig config,
) {
  final players = <Player>[];
  final roleIds = scenario.getExpandedRoles();
  roleIds.shuffle(); // 随机打乱角色顺序

  for (int i = 0; i < roleIds.length; i++) {
    final playerNumber = i + 1;
    final playerName = '${playerNumber}号玩家';
    final roleId = roleIds[i];
    final role = scenario.createRole(roleId);

    // 获取玩家专属的LLM配置
    final playerLLMConfig = config.getPlayerLLMConfig(playerNumber);
    final playerModelConfig = PlayerModelConfig.fromMap(playerLLMConfig);

    // 创建LLM服务和Prompt管理器
    final llmService = OpenAIService.fromPlayerConfig(playerModelConfig);
    final promptManager = PromptManager();

    final player = EnhancedAIPlayer(
      name: playerName,
      role: role,
      llmService: llmService,
      promptManager: promptManager,
      modelConfig: playerModelConfig,
    );

    players.add(player);
  }

  return players;
}
