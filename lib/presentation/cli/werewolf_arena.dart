import 'dart:io';
import 'dart:async';

import 'package:args/args.dart';
import '../../core/engine/game_engine.dart';
import '../../core/state/game_state.dart';
import '../../core/engine/game_engine_callbacks.dart';
import '../../infrastructure/llm/llm_service.dart';
import '../../infrastructure/llm/prompt_manager.dart';
import '../../entities/player/ai_player.dart';
import '../../entities/player/player.dart';
import '../../entities/player/role.dart';
import '../../infrastructure/config/config.dart';
import '../../infrastructure/logging/logger.dart';
import '../../shared/random_helper.dart';
import '../console/game_console.dart';
import '../console/console_callback_handler.dart';

/// Werewolf game main program
class WerewolfArenaGame {
  late final ConfigManager configManager;
  late final GameEngine engine;
  late final OpenAIService llmService;
  late final PromptManager promptManager;
  late final GameConsole console;
  late final ConsoleCallbackHandler consoleCallback;
  late final CompositeGameEventCallbacks compositeCallbacks;

  bool _isRunning = false;

  WerewolfArenaGame();

  /// Initialize application
  Future<void> initialize(List<String> args) async {
    // Parse command line arguments
    final parsedArgs = _parseArguments(args);

    // Initialize configuration system
    configManager = ConfigManager.instance;
    await configManager.initialize();

    // Set scenario if specified
    final scenarioId = parsedArgs['scenario'];
    final playerCount = int.tryParse(parsedArgs['players'] ?? '') ?? 12;

    if (scenarioId != null) {
      configManager.setCurrentScenario(scenarioId);
    } else {
      // Auto-select scenario based on player count
      final availableScenarios =
          configManager.getAvailableScenarios(playerCount);
      if (availableScenarios.isNotEmpty) {
        configManager.setCurrentScenario(availableScenarios.first.id);
        LoggerUtil.instance.i('自动选择场景: ${availableScenarios.first.name}');
      } else {
        LoggerUtil.instance.e('没有找到适合 $playerCount 名玩家的场景');
        exit(1);
      }
    }

    final gameConfig = configManager.gameConfig;
    final llmConfig = configManager.llmConfig;

    // Determine log level - use debug if debug flag is set
    final logLevel =
        parsedArgs['debug'] == true ? 'debug' : gameConfig.loggingConfig.level;

    // Initialize unified logger
    LoggerUtil.instance.initialize(
      enableConsole: false, // 禁用控制台输出，由 Console 模块处理
      enableFile: gameConfig.loggingConfig.enableFile,
      useColors: gameConfig.uiConfig.enableColors,
      logLevel: logLevel,
    );

    // Log debug mode status
    if (parsedArgs['debug'] == true) {
      LoggerUtil.instance.debug('🐛 Debug mode enabled - log level set to DEBUG');
    }

    // Initialize LLM service
    llmService = _createLLMService(llmConfig);

    // Initialize prompt manager
    promptManager = PromptManager();

    // Initialize console system
    console = GameConsole.instance;
    console.initialize(useColors: gameConfig.uiConfig.enableColors);

    // Initialize callback handlers
    consoleCallback = ConsoleCallbackHandler();
    compositeCallbacks = CompositeGameEventCallbacks();
    compositeCallbacks.addCallback(consoleCallback);

    // Initialize game engine with callbacks
    engine = GameEngine(
      configManager: configManager,
      callbacks: compositeCallbacks,
    );
  }

  /// Run application
  Future<void> run() async {
    if (_isRunning) {
      LoggerUtil.instance.w('Application is already running');
      return;
    }

    _isRunning = true;

    try {
      await _runGameLoop();
    } catch (e) {
      LoggerUtil.instance.e('应用程序错误: $e');
    } finally {
      _cleanup();
    }
  }

  /// 游戏主循环
  Future<void> _runGameLoop() async {
    await _createInitialState();

    // 游戏自动开始
    LoggerUtil.instance.debug('游戏初始化完成，自动开始游戏');

    await engine.startGame();

    // 使用新的游戏步骤执行方式
    while (_isRunning && !engine.isGameEnded) {
      await engine.executeGameStep();

      // 小延迟以避免CPU占用过高
      await Future.delayed(const Duration(milliseconds: 100));

      // 检查游戏是否结束
      if (engine.isGameEnded) {
        LoggerUtil.instance.debug('游戏结束');
        _isRunning = false;
      }
    }
  }

  
  /// 创建玩家列表
  List<Player> _createPlayers() {
    final players = <Player>[];
    final random = RandomHelper();
    final currentScenario = configManager.scenario!;

    // 1. 从场景创建角色列表
    final roleIds = currentScenario.getExpandedRoles();

    // 验证角色数量
    if (roleIds.length != currentScenario.playerCount) {
      throw Exception(
          '角色配置不匹配: 需要 ${currentScenario.playerCount} 个角色，但只有 ${roleIds.length} 个');
    }

    // 2. 创建角色实例
    final roles =
        roleIds.map((roleId) => currentScenario.createRole(roleId)).toList();

    // 3. 打乱角色顺序（这样身份分配就是随机的）
    final shuffledRoles = random.shuffle(roles);

    // 4. 创建固定编号的玩家，分配打乱后的角色
    for (int i = 0; i < currentScenario.playerCount; i++) {
      final name = '${i + 1}号玩家'; // 玩家编号固定（1号、2号、3号...）
      final role = shuffledRoles[i]; // 角色是随机打乱的

      // 为每个玩家获取模型配置
      final modelConfig = _getPlayerModelConfig(i + 1, role);

      final player =
          _createEnhancedAIPlayer(name, role, modelConfig: modelConfig);
      players.add(player);
    }
    var message = players.map((player) => player.formattedName).join(', ');
    LoggerUtil.instance.i(message);

    return players;
  }

  /// 获取玩家的模型配置
  PlayerModelConfig? _getPlayerModelConfig(int playerNumber, Role role) {
    // 使用新的配置管理器获取模型配置
    final modelConfigMap = configManager.getPlayerLLMConfig(playerNumber);

    return PlayerModelConfig(
      model: modelConfigMap['model'],
      apiKey: modelConfigMap['api_key'],
      baseUrl: modelConfigMap['base_url'],
      timeoutSeconds: modelConfigMap['timeout_seconds'],
      maxRetries: modelConfigMap['max_retries'],
    );
  }

  /// 创建增强AI玩家
  EnhancedAIPlayer _createEnhancedAIPlayer(String name, Role role,
      {PlayerModelConfig? modelConfig}) {
    return EnhancedAIPlayer(
      name: name,
      role: role,
      llmService: llmService,
      promptManager: promptManager,
      modelConfig: modelConfig,
    );
  }

  /// 创建初始游戏状态
  Future<GameState> _createInitialState() async {
    await engine.initializeGame();

    // Create and set players
    final players = _createPlayers();
    engine.setPlayers(players);

    return engine.currentState!;
  }

  /// 解析命令行参数
  ArgResults _parseArguments(List<String> args) {
    final parser = ArgParser()
      ..addOption('scenario', abbr: 's', help: '游戏场景ID')
      ..addOption('players', abbr: 'p', help: '玩家数量')
      ..addFlag('debug', abbr: 'd', help: '调试模式')
      ..addFlag('test', abbr: 't', help: '测试模式')
      ..addFlag('help', abbr: 'h', help: '显示帮助信息')
      ..addFlag('list-scenarios', help: '列出所有可用场景')
      ..addFlag('colors', help: '启用颜色输出', defaultsTo: true);

    try {
      final results = parser.parse(args);

      // 显示帮助信息
      if (results['help'] == true) {
        _printHelp(parser);
        exit(0);
      }

      // 列出可用场景
      if (results['list-scenarios'] == true) {
        _printScenarios();
        exit(0);
      }

      return results;
    } on FormatException catch (e) {
      LoggerUtil.instance.e('参数解析错误: $e');
      LoggerUtil.instance.i(parser.usage);
      exit(1);
    }
  }

  /// 打印帮助信息
  void _printHelp(ArgParser parser) {
    print('狼人杀竞技场 - AI对战游戏');
    print('');
    print('用法: dart bin/werewolf_arena.dart [选项]');
    print('');
    print('选项:');
    print(parser.usage);
    print('');
    print('示例:');
    print('  dart bin/werewolf_arena.dart --scenario standard_12_players');
    print('  dart bin/werewolf_arena.dart --players 9');
    print('  dart bin/werewolf_arena.dart --debug');
    print('  dart bin/werewolf_arena.dart --list-scenarios');
  }

  /// 打印可用场景列表
  void _printScenarios() {
    final tempConfigManager = ConfigManager.instance;
    try {
      // 临时初始化以获取场景信息
      tempConfigManager.initialize();
      final scenarios =
          tempConfigManager.scenarioManager.getScenarioSummaries();

      if (scenarios.isEmpty) {
        print('没有找到可用的场景配置。');
        return;
      }

      print('可用游戏场景:');
      print('');
      for (final scenario in scenarios) {
        print('ID: ${scenario['id']}');
        print('名称: ${scenario['name']}');
        print('描述: ${scenario['description']}');
        print('玩家数: ${scenario['playerCount']}');
        print('难度: ${scenario['difficulty']}');
        print('标签: ${(scenario['tags'] as List).join(', ')}');
        print('---');
      }
    } catch (e) {
      print('无法加载场景配置: $e');
    }
  }

  /// 创建LLM服务
  OpenAIService _createLLMService(LLMConfig llmConfig) {
    final apiKey = llmConfig.apiKey.isNotEmpty
        ? llmConfig.apiKey
        : Platform.environment['OPENAI_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      LoggerUtil.instance
          .e('未找到OpenAI API密钥，请设置环境变量 OPENAI_API_KEY 或在配置文件中提供API密钥');
      LoggerUtil.instance.e('❌ 错误：未找到OpenAI API密钥');
      LoggerUtil.instance.i('请设置环境变量 OPENAI_API_KEY 或在配置文件中提供API密钥');
      exit(1);
    }

    return OpenAIService(
      apiKey: apiKey,
      model: llmConfig.model,
      baseUrl: llmConfig.baseUrl ?? 'https://api.openai.com/v1',
    );
  }

  /// 清理资源
  void _cleanup() {
    _isRunning = false;

    llmService.dispose();

    engine.dispose();
    LoggerUtil.instance.dispose(); // 确保关闭所有日志文件
    LoggerUtil.instance.debug('应用程序已清理');
  }
}

Future<void> main(List<String> arguments) async {
  final game = WerewolfArenaGame();
  try {
    await game.initialize(arguments);
    await game.run();
  } catch (e) {
    LoggerUtil.instance.e('Game initialization failed: $e');
    exit(1);
  } finally {
    exit(0);
  }
}
