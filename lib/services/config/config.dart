import 'dart:io'
    if (dart.library.html) 'package:werewolf_arena/services/config/platform_io_stub.dart';
import 'package:yaml/yaml.dart';
import 'package:werewolf_arena/core/engine/game_scenario.dart';
import 'package:werewolf_arena/core/rules/game_scenario_manager.dart';
import 'package:werewolf_arena/core/engine/game_parameters.dart';
import 'package:werewolf_arena/services/config/preference_loader.dart';

/// 应用统一配置
class AppConfig {
  // LLM 默认配置
  final String defaultModel;
  final String defaultApiKey;
  final String? defaultBaseUrl;
  final int timeoutSeconds;
  final int maxRetries;

  // 玩家专属 LLM 配置
  final Map<String, PlayerLLMConfig> playerModels;

  // 日志配置
  final LoggingConfig logging;

  AppConfig({
    required this.defaultModel,
    required this.defaultApiKey,
    this.defaultBaseUrl,
    required this.timeoutSeconds,
    required this.maxRetries,
    required this.playerModels,
    required this.logging,
  });

  /// 从 YAML 文件加载配置
  static AppConfig loadFromFile(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw Exception('配置文件不存在: $configPath');
    }

    final yamlString = file.readAsStringSync();
    final yamlMap = loadYaml(yamlString) as YamlMap;

    return AppConfig._fromYaml(yamlMap);
  }

  /// 从 YamlMap 创建配置
  factory AppConfig._fromYaml(YamlMap yaml) {
    // 解析默认 LLM 配置
    final defaultLLM = yaml['default_llm'] as YamlMap;

    // 安全获取 API key，避免在 Web 平台访问 Platform.environment
    String apiKey = defaultLLM['api_key'] ?? '';
    if (apiKey.isEmpty) {
      try {
        apiKey = Platform.environment['OPENAI_API_KEY'] ?? '';
      } catch (e) {
        // Web 平台不支持 Platform.environment，使用空字符串
        apiKey = '';
      }
    }

    // 解析玩家专属模型配置
    final playerModels = <String, PlayerLLMConfig>{};
    if (yaml['player_models'] != null) {
      final playerModelsYaml = yaml['player_models'] as YamlMap;
      for (final entry in playerModelsYaml.entries) {
        final playerKey = entry.key as String;
        final playerConfig = entry.value as YamlMap;
        playerModels[playerKey] = PlayerLLMConfig._fromYaml(playerConfig);
      }
    }

    // 解析日志配置
    final loggingYaml =
        yaml['logging'] as YamlMap? ?? YamlMap.wrap(_getDefaultLoggingConfig());

    return AppConfig(
      defaultModel: defaultLLM['model'] ?? 'gpt-3.5-turbo',
      defaultApiKey: apiKey,
      defaultBaseUrl: defaultLLM['base_url'],
      timeoutSeconds: defaultLLM['timeout_seconds'] ?? 30,
      maxRetries: defaultLLM['max_retries'] ?? 3,
      playerModels: playerModels,
      logging: LoggingConfig._fromYaml(loggingYaml),
    );
  }

  /// 从 YamlMap 创建配置（用于 Web 平台）
  factory AppConfig.fromYamlMap(YamlMap yaml) {
    return AppConfig._fromYaml(yaml);
  }

  /// 创建默认配置（用于 Web 平台）
  factory AppConfig.defaults() {
    return AppConfig._fromYaml(
      YamlMap.wrap({
        'default_llm': {
          'model': 'gpt-3.5-turbo',
          'api_key': '',
          'base_url': null,
          'timeout_seconds': 30,
          'max_retries': 3,
        },
        'player_models': {},
        'logging': _getDefaultLoggingConfig(),
      }),
    );
  }

  static Map<String, dynamic> _getDefaultLoggingConfig() {
    return {
      'level': 'info',
      'enable_console': true,
      'enable_file': true,
      'backup_count': 5,
    };
  }

  /// 序列化为 JSON（用于 SharedPreferences）
  Map<String, dynamic> toJson() {
    return {
      'defaultModel': defaultModel,
      'defaultApiKey': defaultApiKey,
      'defaultBaseUrl': defaultBaseUrl,
      'timeoutSeconds': timeoutSeconds,
      'maxRetries': maxRetries,
      'playerModels': playerModels.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'logging': logging.toJson(),
    };
  }

  /// 从 JSON 反序列化（用于 SharedPreferences）
  static AppConfig fromJson(Map<String, dynamic> json) {
    final playerModelsJson =
        json['playerModels'] as Map<String, dynamic>? ?? {};
    final playerModels = playerModelsJson.map(
      (key, value) => MapEntry(
        key,
        PlayerLLMConfig.fromJson(value as Map<String, dynamic>),
      ),
    );

    return AppConfig(
      defaultModel: json['defaultModel'],
      defaultApiKey: json['defaultApiKey'],
      defaultBaseUrl: json['defaultBaseUrl'],
      timeoutSeconds: json['timeoutSeconds'],
      maxRetries: json['maxRetries'],
      playerModels: playerModels,
      logging: LoggingConfig.fromJson(json['logging']),
    );
  }

  /// 获取指定玩家的 LLM 配置
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber) {
    final playerKey = playerNumber.toString();

    // 如果有玩家专属配置，使用专属配置
    if (playerModels.containsKey(playerKey)) {
      final playerConfig = playerModels[playerKey]!;
      return {
        'model': playerConfig.model,
        'api_key': playerConfig.apiKey,
        'base_url': playerConfig.baseUrl,
        'timeout_seconds': timeoutSeconds,
        'max_retries': maxRetries,
      };
    }

    // 否则使用默认配置
    return {
      'model': defaultModel,
      'api_key': defaultApiKey,
      'base_url': defaultBaseUrl,
      'timeout_seconds': timeoutSeconds,
      'max_retries': maxRetries,
    };
  }
}

/// 玩家专属 LLM 配置
class PlayerLLMConfig {
  final String model;
  final String apiKey;
  final String? baseUrl;

  PlayerLLMConfig({required this.model, required this.apiKey, this.baseUrl});

  factory PlayerLLMConfig._fromYaml(YamlMap yaml) {
    return PlayerLLMConfig(
      model: yaml['model'] ?? '',
      apiKey: yaml['api_key'] ?? '',
      baseUrl: yaml['base_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'model': model, 'apiKey': apiKey, 'baseUrl': baseUrl};
  }

  static PlayerLLMConfig fromJson(Map<String, dynamic> json) {
    return PlayerLLMConfig(
      model: json['model'],
      apiKey: json['apiKey'],
      baseUrl: json['baseUrl'],
    );
  }
}

/// 日志配置
class LoggingConfig {
  final String level;
  final bool enableConsole;
  final bool enableFile;
  final int maxLogFiles;

  LoggingConfig({
    required this.level,
    required this.enableConsole,
    required this.enableFile,
    required this.maxLogFiles,
  });

  factory LoggingConfig._fromYaml(YamlMap yaml) {
    return LoggingConfig(
      level: yaml['level'] ?? 'info',
      enableConsole: yaml['enable_console'] ?? true,
      enableFile: yaml['enable_file'] ?? true,
      maxLogFiles: yaml['backup_count'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'enableConsole': enableConsole,
      'enableFile': enableFile,
      'maxLogFiles': maxLogFiles,
    };
  }

  static LoggingConfig fromJson(Map<String, dynamic> json) {
    return LoggingConfig(
      level: json['level'],
      enableConsole: json['enableConsole'],
      enableFile: json['enableFile'],
      maxLogFiles: json['maxLogFiles'],
    );
  }
}

/// Flutter 游戏参数实现（用于 GUI 应用）
///
/// 使用 SharedPreferences 进行配置持久化，适用于 Flutter 跨平台应用。
///
/// 使用方式：
/// ```dart
/// final parameters = FlutterGameParameters.instance;
/// await parameters.initialize();
/// ```
class FlutterGameParameters implements GameParameters {
  @override
  late AppConfig config;

  @override
  late final ScenarioManager scenarioManager;

  @override
  GameScenario? currentScenario;

  PreferenceConfigLoader? _configLoader;

  FlutterGameParameters._();

  static FlutterGameParameters? _instance;
  static FlutterGameParameters get instance {
    _instance ??= FlutterGameParameters._();
    return _instance!;
  }

  /// 初始化配置系统（GUI 应用使用 SharedPreferences）
  @override
  Future<void> initialize() async {
    // GUI 应用始终使用 SharedPreferences
    _configLoader = PreferenceConfigLoader();

    // 加载配置
    config = await _configLoader!.loadConfig();

    // 初始化场景管理器
    scenarioManager = ScenarioManager();
    scenarioManager.initialize();
  }

  /// 保存配置（GUI 端）
  @override
  Future<void> saveConfig(AppConfig newConfig) async {
    if (_configLoader != null) {
      await _configLoader!.saveConfig(newConfig);
      config = newConfig;
    }
  }

  /// 设置当前场景
  @override
  void setCurrentScenario(String scenarioId) {
    final scenario = scenarioManager.getScenario(scenarioId);
    if (scenario == null) {
      throw Exception('场景不存在: $scenarioId');
    }
    currentScenario = scenario;
  }

  /// 获取当前场景
  @override
  GameScenario? get scenario => currentScenario;

  /// 获取适合指定玩家数量的场景
  @override
  List<GameScenario> getAvailableScenarios(int playerCount) {
    return scenarioManager.getScenariosByPlayerCount(playerCount);
  }

  /// 为指定玩家获取 LLM 配置
  @override
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber) {
    return config.getPlayerLLMConfig(playerNumber);
  }
}
