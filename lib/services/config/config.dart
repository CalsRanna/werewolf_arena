import 'dart:io'
    if (dart.library.html) 'package:werewolf_arena/services/config/platform_io_stub.dart';
import 'package:yaml/yaml.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
// import 'package:werewolf_arena/core/scenarios/scenario_registry.dart'; // 已删除
// import 'package:werewolf_arena/core/engine/game_parameters.dart'; // 已删除
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

    // 解析玩家专属配置
    final playerModels = <String, PlayerLLMConfig>{};
    final playerModelYaml = yaml['player_models'] as YamlMap?;
    if (playerModelYaml != null) {
      for (final entry in playerModelYaml.entries) {
        final playerNumber = entry.key as String;
        final config = entry.value as YamlMap;
        playerModels[playerNumber] = PlayerLLMConfig._fromYaml(config);
      }
    }

    // 解析日志配置
    final loggingYaml = yaml['logging'] as YamlMap?;
    final logging = loggingYaml != null
        ? LoggingConfig._fromYaml(loggingYaml)
        : LoggingConfig.defaultConfig();

    return AppConfig(
      defaultModel: defaultLLM['model'] as String,
      defaultApiKey: defaultLLM['api_key'] as String,
      defaultBaseUrl: defaultLLM['base_url'] as String?,
      timeoutSeconds: defaultLLM['timeout_seconds'] as int? ?? 30,
      maxRetries: defaultLLM['max_retries'] as int? ?? 3,
      playerModels: playerModels,
      logging: logging,
    );
  }

  /// 转换为 JSON 格式用于 SharedPreferences 存储
  Map<String, dynamic> toJson() {
    return {
      'default_llm': {
        'model': defaultModel,
        'api_key': defaultApiKey,
        'base_url': defaultBaseUrl,
        'timeout_seconds': timeoutSeconds,
        'max_retries': maxRetries,
      },
      'player_models': playerModels.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'logging': logging.toJson(),
    };
  }

  /// 从 JSON 创建配置
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final defaultLLM = json['default_llm'] as Map<String, dynamic>;

    // 解析玩家专属配置
    final playerModels = <String, PlayerLLMConfig>{};
    final playerModelJson = json['player_models'] as Map<String, dynamic>?;
    if (playerModelJson != null) {
      for (final entry in playerModelJson.entries) {
        final playerNumber = entry.key;
        final config = entry.value as Map<String, dynamic>;
        playerModels[playerNumber] = PlayerLLMConfig.fromJson(config);
      }
    }

    // 解析日志配置
    final loggingJson = json['logging'] as Map<String, dynamic>?;
    final logging = loggingJson != null
        ? LoggingConfig.fromJson(loggingJson)
        : LoggingConfig.defaultConfig();

    return AppConfig(
      defaultModel: defaultLLM['model'] as String,
      defaultApiKey: defaultLLM['api_key'] as String,
      defaultBaseUrl: defaultLLM['base_url'] as String?,
      timeoutSeconds: defaultLLM['timeout_seconds'] as int? ?? 30,
      maxRetries: defaultLLM['max_retries'] as int? ?? 3,
      playerModels: playerModels,
      logging: logging,
    );
  }

  /// 获取指定玩家的 LLM 配置
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber) {
    // 查找玩家专属配置
    final playerKey = playerNumber.toString();
    if (playerModels.containsKey(playerKey)) {
      final playerConfig = playerModels[playerKey]!;
      return {
        'model': playerConfig.model,
        'api_key': playerConfig.apiKey,
        'base_url': playerConfig.baseUrl,
        'max_retries': playerConfig.maxRetries ?? maxRetries,
        'timeout_seconds': playerConfig.timeoutSeconds ?? timeoutSeconds,
      };
    }

    // 使用默认配置
    return {
      'model': defaultModel,
      'api_key': defaultApiKey,
      'base_url': defaultBaseUrl,
      'max_retries': maxRetries,
      'timeout_seconds': timeoutSeconds,
    };
  }

  /// 创建默认配置
  factory AppConfig.defaultConfig() {
    return AppConfig(
      defaultModel: 'gpt-3.5-turbo',
      defaultApiKey: '',
      defaultBaseUrl: 'https://api.openai.com/v1',
      timeoutSeconds: 30,
      maxRetries: 3,
      playerModels: {},
      logging: LoggingConfig.defaultConfig(),
    );
  }

  /// 兼容性方法：defaults()
  static AppConfig defaults() => AppConfig.defaultConfig();
}

/// 玩家专属 LLM 配置
class PlayerLLMConfig {
  final String model;
  final String apiKey;
  final String? baseUrl;
  final int? maxRetries;
  final int? timeoutSeconds;

  PlayerLLMConfig({
    required this.model,
    required this.apiKey,
    this.baseUrl,
    this.maxRetries,
    this.timeoutSeconds,
  });

  /// 从 YamlMap 创建配置
  factory PlayerLLMConfig._fromYaml(YamlMap yaml) {
    return PlayerLLMConfig(
      model: yaml['model'] as String,
      apiKey: yaml['api_key'] as String,
      baseUrl: yaml['base_url'] as String?,
      maxRetries: yaml['max_retries'] as int?,
      timeoutSeconds: yaml['timeout_seconds'] as int?,
    );
  }

  /// 转换为 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'api_key': apiKey,
      'base_url': baseUrl,
      'max_retries': maxRetries,
      'timeout_seconds': timeoutSeconds,
    };
  }

  /// 从 JSON 创建配置
  factory PlayerLLMConfig.fromJson(Map<String, dynamic> json) {
    return PlayerLLMConfig(
      model: json['model'] as String,
      apiKey: json['api_key'] as String,
      baseUrl: json['base_url'] as String?,
      maxRetries: json['max_retries'] as int?,
      timeoutSeconds: json['timeout_seconds'] as int?,
    );
  }
}

/// 日志配置
class LoggingConfig {
  final String level;
  final bool enableConsole;
  final bool enableFile;
  final int backupCount;
  final int maxLogFiles;

  LoggingConfig({
    required this.level,
    required this.enableConsole,
    required this.enableFile,
    required this.backupCount,
    required this.maxLogFiles,
  });

  /// 从 YamlMap 创建配置
  factory LoggingConfig._fromYaml(YamlMap yaml) {
    return LoggingConfig(
      level: yaml['level'] as String? ?? 'info',
      enableConsole: yaml['enable_console'] as bool? ?? true,
      enableFile: yaml['enable_file'] as bool? ?? true,
      backupCount: yaml['backup_count'] as int? ?? 5,
      maxLogFiles: yaml['max_log_files'] as int? ?? 10,
    );
  }

  /// 转换为 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'enableConsole': enableConsole,
      'enableFile': enableFile,
      'backupCount': backupCount,
      'maxLogFiles': maxLogFiles,
    };
  }

  /// 从 JSON 创建配置
  factory LoggingConfig.fromJson(Map<String, dynamic> json) {
    return LoggingConfig(
      level: json['level'] as String? ?? 'info',
      enableConsole: json['enableConsole'] as bool? ?? true,
      enableFile: json['enableFile'] as bool? ?? true,
      backupCount: json['backupCount'] as int? ?? 5,
      maxLogFiles: json['maxLogFiles'] as int? ?? 10,
    );
  }

  /// 创建默认配置
  factory LoggingConfig.defaultConfig() {
    return LoggingConfig(
      level: 'info',
      enableConsole: true,
      enableFile: true,
      backupCount: 5,
      maxLogFiles: 10,
    );
  }
}