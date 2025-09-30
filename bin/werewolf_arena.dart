import 'dart:io';
import 'dart:async';

import 'package:args/args.dart';
import 'package:werewolf_arena/game/game_engine.dart';
import 'package:werewolf_arena/game/game_state.dart';
import 'package:werewolf_arena/ui/console_ui.dart';
import 'package:werewolf_arena/llm/llm_service.dart';
import 'package:werewolf_arena/llm/prompt_manager.dart';
import 'package:werewolf_arena/player/ai_player.dart';
import 'package:werewolf_arena/player/player.dart';
import 'package:werewolf_arena/player/role.dart';
import 'package:werewolf_arena/utils/config_loader.dart';
import 'package:werewolf_arena/utils/game_logger.dart';
import 'package:werewolf_arena/utils/random_helper.dart';

/// 狼人杀游戏主程序
class WerewolfArenaApp {
  late final GameConfig config;
  late final GameLogger logger;
  late final ConsoleUI ui;
  late final GameEngine gameEngine;
  late final LLMService llmService;
  late final PromptManager promptManager;

  bool _isRunning = false;

  WerewolfArenaApp();

  /// 初始化应用
  Future<void> initialize(List<String> args) async {
    // 解析命令行参数
    final parsedArgs = _parseArguments(args);

    // 加载配置
    config = await _loadConfig(parsedArgs['config']);

    // 初始化日志
    logger = GameLogger(config.loggingConfig);

    // 初始化UI
    ui = ConsoleUI(
      config: config,
      logger: logger,
      consoleWidth: config.uiConfig.consoleWidth,
      useColors: config.uiConfig.enableColors,
    );

    // 初始化LLM服务
    llmService = _createLLMService(config.llmConfig);

    // 初始化提示词管理器
    promptManager = PromptManager();

    // 初始化游戏引擎
    gameEngine = GameEngine(
      config: config,
      logger: logger,
    );

    logger.info('狼人杀竞技场初始化成功');
  }

  /// 运行应用
  Future<void> run() async {
    if (_isRunning) {
      logger.warning('Application is already running');
      return;
    }

    _isRunning = true;

    try {
      await _runGameLoop();
    } catch (e) {
      logger.error('应用程序错误：$e');
      ui.showError('应用程序错误: $e');
    } finally {
      _cleanup();
    }
  }

  /// 游戏主循环
  Future<void> _runGameLoop() async {
    await ui.showGameStart(await _createInitialState());

    // 开始游戏
    await gameEngine.startGame();

    // 主循环 - 直接控制游戏执行，让UI和游戏引擎紧密配合
    while (_isRunning && !gameEngine.isGameEnded) {
      final currentState = gameEngine.currentState!;

      // 根据当前阶段处理游戏逻辑
      switch (currentState.currentPhase) {
        case GamePhase.night:
          await _executeNightPhase(currentState);
          break;
        case GamePhase.day:
          await _executeDayPhase(currentState);
          break;
        case GamePhase.voting:
          await _executeVotingPhase(currentState);
          break;
        case GamePhase.ended:
          await ui.showGameEnd(currentState);
          _isRunning = false;
          continue;
      }

      // 检查游戏是否结束
      if (gameEngine.isGameEnded) {
        await ui.showGameEnd(gameEngine.currentState!);
        _isRunning = false;
      }
    }
  }

  /// 执行夜晚阶段 - UI与游戏引擎同步
  Future<void> _executeNightPhase(GameState state) async {
    // 显示夜晚开始
    ui.clear();
    ui.showBanner('🌙 第 ${state.dayNumber} 夜', color: ConsoleColor.blue);
    ui.showSection('夜晚降临');
    print('天黑请闭眼...');
    ui.showSection('夜晚行动');

    // 执行狼人行动
    final werewolves =
        state.alivePlayers.where((p) => p.role.isWerewolf).toList();
    if (werewolves.isNotEmpty) {
      print('🐺 狼人正在选择击杀目标...');
      await gameEngine.processWerewolfActions();
      print('✅ 狼人行动完成');
    }

    // 执行守卫行动
    final guards =
        state.alivePlayers.where((p) => p.role is GuardRole).toList();
    if (guards.isNotEmpty) {
      print('🛡️ 守卫正在选择守护目标...');
      await gameEngine.processGuardActions();
      print('✅ 守卫行动完成');
    }

    // 执行预言家行动
    final seers = state.alivePlayers.where((p) => p.role is SeerRole).toList();
    if (seers.isNotEmpty) {
      print('🔮 预言家正在查验身份...');
      await gameEngine.processSeerActions();
      print('✅ 预言家行动完成');
    }

    // 执行女巫行动
    final witches =
        state.alivePlayers.where((p) => p.role is WitchRole).toList();
    if (witches.isNotEmpty) {
      print('🧪 女巫正在考虑用药...');
      await gameEngine.processWitchActions();
      print('✅ 女巫行动完成');
    }

    // 结算夜晚行动
    await gameEngine.resolveNightActions();

    // 转到白天
    gameEngine.currentState!.changePhase(GamePhase.day);

    await ui.waitForUserInput('\n按回车键继续...');
  }

  /// 执行白天阶段
  Future<void> _executeDayPhase(GameState state) async {
    await ui.showDayPhase(state);
    await gameEngine.runDiscussionPhase();
    gameEngine.currentState!.changePhase(GamePhase.voting);
  }

  /// 执行投票阶段
  Future<void> _executeVotingPhase(GameState state) async {
    await ui.showVotingPhase(state);
    await gameEngine.collectVotes();
    await gameEngine.resolveVoting();

    // 增加天数，转到夜晚
    gameEngine.currentState!.dayNumber++;
    gameEngine.currentState!.changePhase(GamePhase.night);
  }

  /// 创建玩家列表
  List<Player> _createPlayers() {
    final players = <Player>[];
    final playerNames = _generatePlayerNames(config.playerCount);
    final random = RandomHelper();

    // Create players based on role distribution
    for (final roleEntry in config.roleDistribution.entries) {
      final roleId = roleEntry.key;
      final count = roleEntry.value;

      for (int i = 0; i < count; i++) {
        if (players.length >= config.playerCount) break;

        final role = RoleFactory.createRole(roleId);
        final name = playerNames[players.length];
        final player = _createEnhancedAIPlayer(name, role);
        players.add(player);
      }
    }

    // Fill remaining slots with villagers if needed
    while (players.length < config.playerCount) {
      final name = playerNames[players.length];
      final role = VillagerRole();
      final player = _createEnhancedAIPlayer(name, role);
      players.add(player);
    }

    // Shuffle players for random order
    return random.shuffle(players);
  }

  /// 创建增强AI玩家
  EnhancedAIPlayer _createEnhancedAIPlayer(String name, Role role) {
    final playerId =
        'player_${DateTime.now().millisecondsSinceEpoch}_${RandomHelper().nextString(8)}';

    return EnhancedAIPlayer(
      playerId: playerId,
      name: name,
      role: role,
      llmService: llmService,
      promptManager: promptManager,
      logger: logger,
    );
  }

  /// 生成玩家名称（改为序号制）
  List<String> _generatePlayerNames(int count) {
    final names = <String>[];
    for (int i = 0; i < count; i++) {
      names.add('${i + 1}号玩家');
    }
    return names;
  }

  /// 创建初始游戏状态
  Future<GameState> _createInitialState() async {
    await gameEngine.initializeGame();

    // Create and set players
    final players = _createPlayers();
    gameEngine.setPlayers(players);

    return gameEngine.currentState!;
  }

  /// 解析命令行参数
  ArgResults _parseArguments(List<String> args) {
    final parser = ArgParser()
      ..addOption('config', abbr: 'c', help: '配置文件路径')
      ..addOption('players', abbr: 'p', help: '玩家数量')
      ..addFlag('debug', abbr: 'd', help: '调试模式')
      ..addFlag('test', abbr: 't', help: '测试模式')
      ..addFlag('help', abbr: 'h', help: '显示帮助信息')
      ..addFlag('colors', help: '启用颜色输出', defaultsTo: true);

    try {
      return parser.parse(args);
    } on FormatException catch (e) {
      print('参数解析错误: $e');
      print(parser.usage);
      exit(1);
    }
  }

  /// 加载配置
  Future<GameConfig> _loadConfig(String? configPath) async {
    if (configPath != null) {
      return GameConfig.loadFromFile(configPath);
    } else {
      return GameConfig.loadDefault();
    }
  }

  /// 创建LLM服务
  LLMService _createLLMService(LLMConfig llmConfig) {
    final apiKey = llmConfig.apiKey.isNotEmpty
        ? llmConfig.apiKey
        : Platform.environment['OPENAI_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      logger.error('未找到OpenAI API密钥，请设置环境变量 OPENAI_API_KEY 或在配置文件中提供API密钥');
      print('❌ 错误：未找到OpenAI API密钥');
      print('请设置环境变量 OPENAI_API_KEY 或在配置文件中提供API密钥');
      exit(1);
    }

    return OpenAIService(
      apiKey: apiKey,
      model: llmConfig.model,
      logger: logger,
    );
  }

  /// 清理资源
  void _cleanup() {
    _isRunning = false;

    if (llmService is OpenAIService) {
      (llmService as OpenAIService).dispose();
    }

    gameEngine.dispose();
    logger.dispose(); // 确保关闭所有日志文件
    logger.info('应用程序已清理');
  }

  /// 显示帮助信息
  void _showHelp() {
    print('''
🐺 狼人杀游戏 - LLM版本

用法: dart run bin/werewolf_arena.dart [选项]

选项:
  -c, --config <path>    配置文件路径
  -p, --players <num>    玩家数量 (6-12, 默认12人局)
  -d, --debug           启用调试模式
  -t, --test            启用测试模式
  --colors              启用颜色输出 (默认: true)
  -h, --help            显示帮助信息

环境变量:
  OPENAI_API_KEY         OpenAI API密钥 (必需)

示例:
  dart run bin/werewolf_arena.dart
  dart run bin/werewolf_arena.dart --players 8
  dart run bin/werewolf_arena.dart --config config/custom_config.yaml
  OPENAI_API_KEY=your_key dart run bin/werewolf_arena.dart

游戏配置 (12人局):
  • 4名平民 + 4名狼人 + 4名神职 (预言家、女巫、猎人、守卫)
  • 行动顺序: 1-12顺序 (可在配置文件中改为12-1逆序)
  • 所有AI玩家都由真实的LLM服务驱动，具备完整策略思维
  • 严格的身份隐藏策略，符合高水平狼人杀规则

游戏说明:
  • 你将以上帝视角观察AI玩家进行狼人杀游戏
  • 每个回合结束后需要按回车键继续
  • 游戏会自动进行直到某一阵营获胜
  • 在调试模式下可以看到更详细的信息

按 Ctrl+C 可以随时退出游戏。
''');
  }
}

/// 主函数
void main(List<String> arguments) async {
  final app = WerewolfArenaApp();

  try {
    await app.initialize(arguments);

    // 检查是否需要显示帮助
    if (arguments.contains('--help') || arguments.contains('-h')) {
      app._showHelp();
      return;
    }

    await app.run();
  } catch (e) {
    print('❌ 程序启动失败: $e');
    exit(1);
  } finally {
    // 确保程序正常退出
    exit(0);
  }
}
