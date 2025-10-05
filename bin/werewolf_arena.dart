import 'dart:io';
import 'dart:async';

import 'package:args/args.dart';
import 'package:werewolf_arena/game/game_engine.dart';
import 'package:werewolf_arena/game/game_state.dart';
import 'package:werewolf_arena/llm/llm_service.dart';
import 'package:werewolf_arena/llm/prompt_manager.dart';
import 'package:werewolf_arena/player/ai_player.dart';
import 'package:werewolf_arena/player/player.dart';
import 'package:werewolf_arena/player/role.dart';
import 'package:werewolf_arena/utils/config_loader.dart';
import 'package:werewolf_arena/utils/logger_util.dart';
import 'package:werewolf_arena/utils/random_helper.dart';

/// Werewolf game main program
class WerewolfArenaGame {
  late final GameConfig config;
  late final GameEngine engine;
  late final LLMService llmService;
  late final PromptManager promptManager;

  bool _isRunning = false;

  WerewolfArenaGame();

  /// Initialize application
  Future<void> initialize(List<String> args) async {
    // Parse command line arguments
    final parsedArgs = _parseArguments(args);

    // Load configuration
    config = await _loadConfig(parsedArgs['config']);

    // Initialize unified logger
    LoggerUtil.instance.initialize(
      enableConsole: true,
      enableFile: config.loggingConfig.enableFile,
      useColors: config.uiConfig.enableColors,
      logLevel: config.loggingConfig.level,
      logFilePath: config.loggingConfig.logFilePath,
    );

    // Initialize LLM service
    llmService = _createLLMService(config.llmConfig);

    // Initialize prompt manager
    promptManager = PromptManager();

    // Initialize game engine
    engine = GameEngine(config: config);

    LoggerUtil.instance.i('Werewolf Arena initialized successfully');
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
    LoggerUtil.instance.i('游戏初始化完成，自动开始游戏...');

    await engine.startGame();

    while (_isRunning && !engine.isGameEnded) {
      final currentState = engine.currentState!;

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
          LoggerUtil.instance.i('🎊 Game Over');
          LoggerUtil.instance.i('Game ended successfully');
          _isRunning = false;
          continue;
      }

      // 检查游戏是否结束
      if (engine.isGameEnded) {
        LoggerUtil.instance.i('🎊 Game Over');
        LoggerUtil.instance.i('Game ended successfully');
        _isRunning = false;
      }
    }
  }

  /// 执行夜晚阶段 - UI与游戏引擎同步
  Future<void> _executeNightPhase(GameState state) async {
    LoggerUtil.instance.i('第${state.dayNumber}天夜晚');
    LoggerUtil.instance.i('[法官]: 天黑请闭眼');

    // Execute complete night phase with all role actions
    await engine.processWerewolfActions();
    await engine.processGuardActions();
    await engine.processSeerActions();
    await engine.processWitchActions();

    // Resolve all night actions
    await engine.resolveNightActions();

    // Check for game end condition after night actions resolve
    if (state.checkGameEnd()) {
      _isRunning = false;
      return;
    }

    // Move to day phase
    await engine.currentState!.changePhase(GamePhase.day);
  }

  /// 执行白天阶段
  Future<void> _executeDayPhase(GameState state) async {
    LoggerUtil.instance.i('第${state.dayNumber}天白天');
    LoggerUtil.instance.i('[法官]: 天亮了');
    await engine.runDiscussionPhase();

    // Check for game end condition after discussion
    if (state.checkGameEnd()) {
      _isRunning = false;
      return;
    }

    await engine.currentState!.changePhase(GamePhase.voting);
  }

  /// 执行投票阶段
  Future<void> _executeVotingPhase(GameState state) async {
    LoggerUtil.instance.i('[法官]: 现在开始投票');
    await engine.collectVotes();
    await engine.resolveVoting();

    // Check for game end condition after voting resolution
    if (state.checkGameEnd()) {
      _isRunning = false;
      return;
    }

    // 增加天数，转到夜晚
    engine.currentState!.dayNumber++;
    await engine.currentState!.changePhase(GamePhase.night);
  }

  /// 创建玩家列表
  List<Player> _createPlayers() {
    final players = <Player>[];
    final random = RandomHelper();

    // 1. 创建角色列表
    final roles = <Role>[];
    for (final roleEntry in config.roleDistribution.entries) {
      final roleId = roleEntry.key;
      final count = roleEntry.value;

      for (int i = 0; i < count; i++) {
        if (roles.length >= config.playerCount) break;
        final role = RoleFactory.createRole(roleId);
        roles.add(role);
      }
    }

    // 填充剩余位置为村民
    while (roles.length < config.playerCount) {
      roles.add(VillagerRole());
    }

    // 2. 打乱角色顺序（这样身份分配就是随机的）
    final shuffledRoles = random.shuffle(roles);

    // 3. 创建固定编号的玩家，分配打乱后的角色
    for (int i = 0; i < config.playerCount; i++) {
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
    // 首先尝试从配置中获取玩家特定的模型配置
    if (config.playerModelConfigs != null &&
        config.playerModelConfigs!.containsKey(playerNumber.toString())) {
      final playerConfig = config.playerModelConfigs![playerNumber.toString()];
      return PlayerModelConfig.fromMap(playerConfig!);
    }

    // 尝试从角色特定的模型配置中获取
    if (config.roleModelConfigs != null &&
        config.roleModelConfigs!.containsKey(role.roleId)) {
      final roleConfig = config.roleModelConfigs![role.roleId];
      return PlayerModelConfig.fromMap(roleConfig!);
    }

    // 如果没有特定配置，使用默认的LLM配置
    return PlayerModelConfig(
      model: config.llmConfig.model,
      apiKey: config.llmConfig.apiKey,
      temperature: config.llmConfig.temperature,
      maxTokens: config.llmConfig.maxTokens,
      timeoutSeconds: config.llmConfig.timeoutSeconds,
      maxRetries: config.llmConfig.maxRetries,
    );
  }

  /// 创建增强AI玩家
  EnhancedAIPlayer _createEnhancedAIPlayer(String name, Role role,
      {PlayerModelConfig? modelConfig}) {
    final playerId =
        'player_${DateTime.now().millisecondsSinceEpoch}_${RandomHelper().nextString(8)}';

    return EnhancedAIPlayer(
      playerId: playerId,
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
      ..addOption('config', abbr: 'c', help: '配置文件路径')
      ..addOption('players', abbr: 'p', help: '玩家数量')
      ..addFlag('debug', abbr: 'd', help: '调试模式')
      ..addFlag('test', abbr: 't', help: '测试模式')
      ..addFlag('help', abbr: 'h', help: '显示帮助信息')
      ..addFlag('colors', help: '启用颜色输出', defaultsTo: true);

    try {
      return parser.parse(args);
    } on FormatException catch (e) {
      LoggerUtil.instance.e('参数解析错误: $e');
      LoggerUtil.instance.i(parser.usage);
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
      LoggerUtil.instance
          .e('未找到OpenAI API密钥，请设置环境变量 OPENAI_API_KEY 或在配置文件中提供API密钥');
      LoggerUtil.instance.e('❌ 错误：未找到OpenAI API密钥');
      LoggerUtil.instance.i('请设置环境变量 OPENAI_API_KEY 或在配置文件中提供API密钥');
      exit(1);
    }

    return OpenAIService(
      apiKey: apiKey,
      model: llmConfig.model,
    );
  }

  /// 清理资源
  void _cleanup() {
    _isRunning = false;

    if (llmService is OpenAIService) {
      (llmService as OpenAIService).dispose();
    }

    engine.dispose();
    LoggerUtil.instance.dispose(); // 确保关闭所有日志文件
    LoggerUtil.instance.i('应用程序已清理');
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
