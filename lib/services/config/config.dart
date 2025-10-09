import 'dart:io' if (dart.library.html) 'package:werewolf_arena/services/config/platform_io_stub.dart';
import 'package:yaml/yaml.dart';
import 'package:werewolf_arena/core/rules/game_scenario.dart';
import 'package:werewolf_arena/core/rules/game_scenario_manager.dart';
import 'package:werewolf_arena/services/config/config_loader.dart';

/// 游戏基础配置（只包含UI和日志设置）
class GameConfig {
  final UIConfig uiConfig;
  final LoggingConfig loggingConfig;
  final DevelopmentConfig developmentConfig;

  GameConfig({
    required this.uiConfig,
    required this.loggingConfig,
    required this.developmentConfig,
  });

  static GameConfig loadFromFile(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw Exception('游戏配置文件不存在: $configPath');
    }

    final yamlString = file.readAsStringSync();
    final yamlMap = loadYaml(yamlString) as YamlMap;

    return GameConfig._fromYaml(yamlMap);
  }

  factory GameConfig._fromYaml(YamlMap yaml) {
    final uiConfig =
        yaml['ui'] as YamlMap? ?? YamlMap.wrap(_getDefaultUIConfig());
    final loggingConfig =
        yaml['logging'] as YamlMap? ?? YamlMap.wrap(_getDefaultLoggingConfig());
    final developmentConfig = yaml['development'] as YamlMap? ??
        YamlMap.wrap(_getDefaultDevelopmentConfig());

    return GameConfig(
      uiConfig: UIConfig._fromYaml(uiConfig),
      loggingConfig: LoggingConfig._fromYaml(loggingConfig),
      developmentConfig: DevelopmentConfig._fromYaml(developmentConfig),
    );
  }

  /// 从 YamlMap 创建配置（用于 Web 平台）
  factory GameConfig.fromYamlMap(YamlMap yaml) {
    return GameConfig._fromYaml(yaml);
  }

  /// 创建默认配置（用于 Web 平台）
  factory GameConfig.defaults() {
    return GameConfig._fromYaml(
      YamlMap.wrap({
        'ui': _getDefaultUIConfig(),
        'logging': _getDefaultLoggingConfig(),
        'development': _getDefaultDevelopmentConfig(),
      }),
    );
  }

  static Map<String, dynamic> _getDefaultUIConfig() {
    return {
      'console_width': 80,
      'enable_colors': true,
      'enable_animations': true,
      'show_debug_info': false,
      'log_level': 'info',
      'display': {
        'show_player_status': true,
        'show_game_state': true,
        'show_action_history': true,
        'show_statistics': true,
      }
    };
  }

  static Map<String, dynamic> _getDefaultLoggingConfig() {
    return {
      'level': 'info',
      'enable_console': true,
      'enable_file': true,
      'backup_count': 5,
    };
  }

  static Map<String, dynamic> _getDefaultDevelopmentConfig() {
    return {
      'debug_mode': false,
      'step_by_step': false,
      'auto_start': true,
      'fast_mode': false,
      'testing': {
        'enable_mock_llm': false,
        'deterministic_random': false,
        'save_game_states': false,
      }
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'uiConfig': uiConfig.toJson(),
      'loggingConfig': loggingConfig.toJson(),
      'developmentConfig': developmentConfig.toJson(),
    };
  }

  static GameConfig fromJson(Map<String, dynamic> json) {
    return GameConfig(
      uiConfig: UIConfig.fromJson(json['uiConfig']),
      loggingConfig: LoggingConfig.fromJson(json['loggingConfig']),
      developmentConfig: DevelopmentConfig.fromJson(json['developmentConfig']),
    );
  }
}

/// LLM配置（包含玩家模型配置）
class LLMConfig {
  final String model;
  final String apiKey;
  final String? baseUrl;
  final int timeoutSeconds;
  final int maxRetries;
  final PromptSettings prompts;
  final Map<String, dynamic> llmSettings;
  final Map<String, Map<String, dynamic>> playerModels;

  LLMConfig({
    required this.model,
    required this.apiKey,
    this.baseUrl,
    required this.timeoutSeconds,
    required this.maxRetries,
    required this.prompts,
    required this.llmSettings,
    required this.playerModels,
  });

  static LLMConfig loadFromFile(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw Exception('LLM配置文件不存在: $configPath');
    }

    final yamlString = file.readAsStringSync();
    final yamlMap = loadYaml(yamlString) as YamlMap;

    return LLMConfig._fromYaml(yamlMap);
  }

  factory LLMConfig._fromYaml(YamlMap yaml) {
    final defaultLLMConfig = yaml['default_llm'] as YamlMap;
    final promptsYaml = yaml['prompts'] as YamlMap;
    final llmSettingsYaml = yaml['llm_settings'] as YamlMap? ?? {};

    // 解析玩家模型配置
    final playerModels = <String, Map<String, dynamic>>{};
    if (yaml['player_models'] != null) {
      final playerModelsYaml = yaml['player_models'] as YamlMap;
      for (final entry in playerModelsYaml.entries) {
        playerModels[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }

    // 安全获取 API key，避免在 Web 平台访问 Platform.environment
    String apiKey = defaultLLMConfig['api_key'] ?? '';
    if (apiKey.isEmpty) {
      try {
        apiKey = Platform.environment['OPENAI_API_KEY'] ?? '';
      } catch (e) {
        // Web 平台不支持 Platform.environment，使用空字符串
        apiKey = '';
      }
    }

    return LLMConfig(
      model: defaultLLMConfig['model'] ?? 'gpt-3.5-turbo',
      apiKey: apiKey,
      baseUrl: defaultLLMConfig['base_url'],
      timeoutSeconds: defaultLLMConfig['timeout_seconds'] ?? 30,
      maxRetries: defaultLLMConfig['max_retries'] ?? 3,
      prompts: PromptSettings._fromYaml(promptsYaml),
      llmSettings: Map<String, dynamic>.from(llmSettingsYaml),
      playerModels: playerModels,
    );
  }

  /// 从 YamlMap 创建配置（用于 Web 平台）
  factory LLMConfig.fromYamlMap(YamlMap yaml) {
    return LLMConfig._fromYaml(yaml);
  }

  /// 创建默认配置（用于 Web 平台）
  factory LLMConfig.defaults() {
    return LLMConfig._fromYaml(
      YamlMap.wrap({
        'default_llm': {
          'model': 'gpt-3.5-turbo',
          'api_key': '',
          'base_url': null,
          'timeout_seconds': 30,
          'max_retries': 3,
        },
        'prompts': {
          'enable_context': true,
          'strategy_hints': true,
          'personality_traits': true,
          'base_system_prompt': '',
        },
        'llm_settings': {},
        'player_models': {},
      }),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'timeoutSeconds': timeoutSeconds,
      'maxRetries': maxRetries,
      'prompts': prompts.toJson(),
      'llmSettings': llmSettings,
      'playerModels': playerModels,
    };
  }

  static LLMConfig fromJson(Map<String, dynamic> json) {
    return LLMConfig(
      model: json['model'],
      apiKey: json['apiKey'],
      baseUrl: json['baseUrl'],
      timeoutSeconds: json['timeoutSeconds'],
      maxRetries: json['maxRetries'],
      prompts: PromptSettings.fromJson(json['prompts']),
      llmSettings: Map<String, dynamic>.from(json['llmSettings']),
      playerModels:
          Map<String, Map<String, dynamic>>.from(json['playerModels']),
    );
  }
}

/// 提示词设置
class PromptSettings {
  final bool enableContext;
  final bool strategyHints;
  final bool personalityTraits;
  final String baseSystemPrompt;

  PromptSettings({
    required this.enableContext,
    required this.strategyHints,
    required this.personalityTraits,
    required this.baseSystemPrompt,
  });

  factory PromptSettings._fromYaml(YamlMap yaml) {
    return PromptSettings(
      enableContext: yaml['enable_context'] ?? true,
      strategyHints: yaml['strategy_hints'] ?? true,
      personalityTraits: yaml['personality_traits'] ?? true,
      baseSystemPrompt: yaml['base_system_prompt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableContext': enableContext,
      'strategyHints': strategyHints,
      'personalityTraits': personalityTraits,
      'baseSystemPrompt': baseSystemPrompt,
    };
  }

  static PromptSettings fromJson(Map<String, dynamic> json) {
    return PromptSettings(
      enableContext: json['enableContext'],
      strategyHints: json['strategyHints'],
      personalityTraits: json['personalityTraits'],
      baseSystemPrompt: json['baseSystemPrompt'],
    );
  }
}

/// UI配置
class UIConfig {
  final int consoleWidth;
  final bool enableColors;
  final bool enableAnimations;
  final bool showDebugInfo;
  final String logLevel;
  final DisplaySettings display;

  UIConfig({
    required this.consoleWidth,
    required this.enableColors,
    required this.enableAnimations,
    required this.showDebugInfo,
    required this.logLevel,
    required this.display,
  });

  factory UIConfig._fromYaml(YamlMap yaml) {
    final displayYaml = yaml['display'] as YamlMap?;

    return UIConfig(
      consoleWidth: yaml['console_width'] ?? 80,
      enableColors: yaml['enable_colors'] ?? true,
      enableAnimations: yaml['enable_animations'] ?? true,
      showDebugInfo: yaml['show_debug_info'] ?? false,
      logLevel: yaml['log_level'] ?? 'info',
      display: displayYaml != null
          ? DisplaySettings._fromYaml(displayYaml)
          : DisplaySettings.defaults(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consoleWidth': consoleWidth,
      'enableColors': enableColors,
      'enableAnimations': enableAnimations,
      'showDebugInfo': showDebugInfo,
      'logLevel': logLevel,
      'display': display.toJson(),
    };
  }

  static UIConfig fromJson(Map<String, dynamic> json) {
    return UIConfig(
      consoleWidth: json['consoleWidth'],
      enableColors: json['enableColors'],
      enableAnimations: json['enableAnimations'],
      showDebugInfo: json['showDebugInfo'],
      logLevel: json['logLevel'],
      display: DisplaySettings.fromJson(json['display']),
    );
  }
}

/// 显示设置
class DisplaySettings {
  final bool showPlayerStatus;
  final bool showGameState;
  final bool showActionHistory;
  final bool showStatistics;

  DisplaySettings({
    required this.showPlayerStatus,
    required this.showGameState,
    required this.showActionHistory,
    required this.showStatistics,
  });

  factory DisplaySettings._fromYaml(YamlMap yaml) {
    return DisplaySettings(
      showPlayerStatus: yaml['show_player_status'] ?? true,
      showGameState: yaml['show_game_state'] ?? true,
      showActionHistory: yaml['show_action_history'] ?? true,
      showStatistics: yaml['show_statistics'] ?? true,
    );
  }

  static DisplaySettings defaults() {
    return DisplaySettings(
      showPlayerStatus: true,
      showGameState: true,
      showActionHistory: true,
      showStatistics: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showPlayerStatus': showPlayerStatus,
      'showGameState': showGameState,
      'showActionHistory': showActionHistory,
      'showStatistics': showStatistics,
    };
  }

  static DisplaySettings fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      showPlayerStatus: json['showPlayerStatus'],
      showGameState: json['showGameState'],
      showActionHistory: json['showActionHistory'],
      showStatistics: json['showStatistics'],
    );
  }
}

/// 日志配置
class LoggingConfig {
  final String level;
  final bool enableConsole;
  final bool enableFile;
  final int maxLogSizeMb;
  final int maxLogFiles;

  LoggingConfig({
    required this.level,
    required this.enableConsole,
    required this.enableFile,
    required this.maxLogSizeMb,
    required this.maxLogFiles,
  });

  factory LoggingConfig._fromYaml(YamlMap yaml) {
    return LoggingConfig(
      level: yaml['level'] ?? 'info',
      enableConsole: yaml['enable_console'] ?? true,
      enableFile: yaml['enable_file'] ?? true,
      maxLogSizeMb: 10,
      maxLogFiles: yaml['backup_count'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'enableConsole': enableConsole,
      'enableFile': enableFile,
      'maxLogSizeMb': maxLogSizeMb,
      'maxLogFiles': maxLogFiles,
    };
  }

  static LoggingConfig fromJson(Map<String, dynamic> json) {
    return LoggingConfig(
      level: json['level'],
      enableConsole: json['enableConsole'],
      enableFile: json['enableFile'],
      maxLogSizeMb: json['maxLogSizeMb'],
      maxLogFiles: json['maxLogFiles'],
    );
  }
}

/// 开发配置
class DevelopmentConfig {
  final bool enableDebugMode;
  final bool enableTestMode;
  final bool mockLlmResponses;
  final bool saveGameStates;
  final int autoSaveInterval;

  DevelopmentConfig({
    required this.enableDebugMode,
    required this.enableTestMode,
    required this.mockLlmResponses,
    required this.saveGameStates,
    required this.autoSaveInterval,
  });

  factory DevelopmentConfig._fromYaml(YamlMap yaml) {
    return DevelopmentConfig(
      enableDebugMode: yaml['debug_mode'] ?? false,
      enableTestMode: false,
      mockLlmResponses: yaml['testing']?['enable_mock_llm'] ?? false,
      saveGameStates: yaml['testing']?['save_game_states'] ?? false,
      autoSaveInterval: 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableDebugMode': enableDebugMode,
      'enableTestMode': enableTestMode,
      'mockLlmResponses': mockLlmResponses,
      'saveGameStates': saveGameStates,
      'autoSaveInterval': autoSaveInterval,
    };
  }

  static DevelopmentConfig fromJson(Map<String, dynamic> json) {
    return DevelopmentConfig(
      enableDebugMode: json['enableDebugMode'],
      enableTestMode: json['enableTestMode'],
      mockLlmResponses: json['mockLlmResponses'],
      saveGameStates: json['saveGameStates'],
      autoSaveInterval: json['autoSaveInterval'],
    );
  }
}

/// 新的配置管理器
class ConfigManager {
  late final GameConfig gameConfig;
  late final LLMConfig llmConfig;
  late final ScenarioManager scenarioManager;
  GameScenario? currentScenario;
  ConfigLoader? _configLoader;

  ConfigManager._();

  static ConfigManager? _instance;
  static ConfigManager get instance {
    _instance ??= ConfigManager._();
    return _instance!;
  }

  /// 初始化配置系统
  Future<void> initialize({
    String? customConfigDir,
    bool? forceConsoleMode,
  }) async {
    // 创建适合当前平台的配置加载器
    _configLoader = ConfigLoaderFactory.create(
      customConfigDir: customConfigDir,
      forceConsole: forceConsoleMode,
    );

    // 加载配置
    gameConfig = await _configLoader!.loadGameConfig();
    llmConfig = await _configLoader!.loadLLMConfig();

    // 初始化场景管理器
    scenarioManager = ScenarioManager();
    scenarioManager.initialize();
  }

  /// 保存游戏配置（仅GUI端有效）
  Future<void> saveGameConfig(GameConfig config) async {
    if (_configLoader != null) {
      await _configLoader!.saveGameConfig(config);
      gameConfig = config;
    }
  }

  /// 保存LLM配置（仅GUI端有效）
  Future<void> saveLLMConfig(LLMConfig config) async {
    if (_configLoader != null) {
      await _configLoader!.saveLLMConfig(config);
      llmConfig = config;
    }
  }

  /// 设置当前场景
  void setCurrentScenario(String scenarioId) {
    final scenario = scenarioManager.getScenario(scenarioId);
    if (scenario == null) {
      throw Exception('场景不存在: $scenarioId');
    }
    currentScenario = scenario;
  }

  /// 获取当前场景
  GameScenario? get scenario => currentScenario;

  /// 获取适合指定玩家数量的场景
  List<GameScenario> getAvailableScenarios(int playerCount) {
    return scenarioManager.getScenariosByPlayerCount(playerCount);
  }

  /// 为指定玩家获取LLM配置
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber) {
    // 使用默认配置
    Map<String, dynamic> config = {
      'model': llmConfig.model,
      'api_key': llmConfig.apiKey,
      'base_url': llmConfig.baseUrl,
      'timeout_seconds': llmConfig.timeoutSeconds,
      'max_retries': llmConfig.maxRetries,
    };

    // 应用玩家特定配置
    String playerKey = playerNumber.toString();
    if (llmConfig.playerModels.containsKey(playerKey)) {
      config.addAll(llmConfig.playerModels[playerKey]!);
    }

    return config;
  }
}
