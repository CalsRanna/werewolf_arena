import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

class GameConfig {
  final int playerCount;
  final Map<String, int> roleDistribution;
  final LLMConfig llmConfig;
  final GameTiming timing;
  final UIConfig uiConfig;
  final LoggingConfig loggingConfig;
  final DevelopmentConfig developmentConfig;
  final ActionOrderConfig actionOrder;
  final Map<String, Map<String, dynamic>>? playerModelConfigs;
  final Map<String, Map<String, dynamic>>? roleModelConfigs;

  GameConfig({
    required this.playerCount,
    required this.roleDistribution,
    required this.llmConfig,
    required this.timing,
    required this.uiConfig,
    required this.loggingConfig,
    required this.developmentConfig,
    required this.actionOrder,
    this.playerModelConfigs,
    this.roleModelConfigs,
  });

  static GameConfig loadFromFile(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw Exception('Configuration file not found: $configPath');
    }

    final yamlString = file.readAsStringSync();
    final yamlMap = loadYaml(yamlString) as YamlMap;

    return GameConfig._fromYaml(yamlMap);
  }

  static GameConfig loadDefault() {
    final configPath =
        path.join(Directory.current.path, 'config', 'default_config.yaml');
    return loadFromFile(configPath);
  }

  factory GameConfig._fromYaml(YamlMap yaml) {
    final gameConfig = yaml['game'] as YamlMap;
    final llmConfig = yaml['llm'] as YamlMap;
    final uiConfig = yaml['ui'] as YamlMap;
    final loggingConfig = yaml['logging'] as YamlMap;
    final developmentConfig = yaml['development'] as YamlMap;

    // Parse player-specific model configurations
    Map<String, Map<String, dynamic>>? playerModelConfigs;
    if (yaml['player_models'] != null) {
      final playerModelsYaml = yaml['player_models'] as YamlMap;
      playerModelConfigs = <String, Map<String, dynamic>>{};
      for (final entry in playerModelsYaml.entries) {
        playerModelConfigs[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }

    // Parse role-specific model configurations
    Map<String, Map<String, dynamic>>? roleModelConfigs;
    if (yaml['role_models'] != null) {
      final roleModelsYaml = yaml['role_models'] as YamlMap;
      roleModelConfigs = <String, Map<String, dynamic>>{};
      for (final entry in roleModelsYaml.entries) {
        roleModelConfigs[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }

    return GameConfig(
      playerCount: gameConfig['player_count'],
      roleDistribution: Map<String, int>.from(gameConfig['roles']),
      llmConfig: LLMConfig._fromYaml(llmConfig),
      timing: GameTiming._fromYaml(gameConfig['timing']),
      uiConfig: UIConfig._fromYaml(uiConfig),
      loggingConfig: LoggingConfig._fromYaml(loggingConfig),
      developmentConfig: DevelopmentConfig._fromYaml(developmentConfig),
      actionOrder: ActionOrderConfig._fromYaml(gameConfig['action_order']),
      playerModelConfigs: playerModelConfigs,
      roleModelConfigs: roleModelConfigs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerCount': playerCount,
      'roleDistribution': roleDistribution,
      'llmConfig': llmConfig.toJson(),
      'timing': timing.toJson(),
      'uiConfig': uiConfig.toJson(),
      'loggingConfig': loggingConfig.toJson(),
      'developmentConfig': developmentConfig.toJson(),
      'actionOrder': actionOrder.toJson(),
      'playerModelConfigs': playerModelConfigs,
      'roleModelConfigs': roleModelConfigs,
    };
  }

  static GameConfig fromJson(Map<String, dynamic> json) {
    return GameConfig(
      playerCount: json['playerCount'],
      roleDistribution: Map<String, int>.from(json['roleDistribution']),
      llmConfig: LLMConfig.fromJson(json['llmConfig']),
      timing: GameTiming.fromJson(json['timing']),
      uiConfig: UIConfig.fromJson(json['uiConfig']),
      loggingConfig: LoggingConfig.fromJson(json['loggingConfig']),
      developmentConfig: DevelopmentConfig.fromJson(json['developmentConfig']),
      actionOrder: ActionOrderConfig.fromJson(json['actionOrder']),
      playerModelConfigs: json['playerModelConfigs'] != null
          ? Map<String, Map<String, dynamic>>.from(json['playerModelConfigs'])
          : null,
      roleModelConfigs: json['roleModelConfigs'] != null
          ? Map<String, Map<String, dynamic>>.from(json['roleModelConfigs'])
          : null,
    );
  }
}

class LLMConfig {
  final String model;
  final String apiKey;
  final int timeoutSeconds;
  final int maxRetries;
  final PromptSettings prompts;

  LLMConfig({
    required this.model,
    required this.apiKey,
    required this.timeoutSeconds,
    required this.maxRetries,
    required this.prompts,
  });

  factory LLMConfig._fromYaml(YamlMap yaml) {
    final promptsYaml = yaml['prompts'] as YamlMap;

    return LLMConfig(
      model: yaml['model'],
      apiKey: yaml['api_key'] ?? Platform.environment['OPENAI_API_KEY'] ?? '',
      timeoutSeconds: yaml['timeout_seconds'],
      maxRetries: yaml['max_retries'],
      prompts: PromptSettings._fromYaml(promptsYaml),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'apiKey': apiKey,
      'timeoutSeconds': timeoutSeconds,
      'maxRetries': maxRetries,
      'prompts': prompts.toJson(),
    };
  }

  static LLMConfig fromJson(Map<String, dynamic> json) {
    return LLMConfig(
      model: json['model'],
      apiKey: json['apiKey'],
      timeoutSeconds: json['timeoutSeconds'],
      maxRetries: json['maxRetries'],
      prompts: PromptSettings.fromJson(json['prompts']),
    );
  }
}

class PromptSettings {
  final bool enableContext;
  final bool strategyHints;
  final bool personalityTraits;

  PromptSettings({
    required this.enableContext,
    required this.strategyHints,
    required this.personalityTraits,
  });

  factory PromptSettings._fromYaml(YamlMap yaml) {
    return PromptSettings(
      enableContext: yaml['enable_context'],
      strategyHints: yaml['strategy_hints'],
      personalityTraits: yaml['personality_traits'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableContext': enableContext,
      'strategyHints': strategyHints,
      'personalityTraits': personalityTraits,
    };
  }

  static PromptSettings fromJson(Map<String, dynamic> json) {
    return PromptSettings(
      enableContext: json['enableContext'],
      strategyHints: json['strategyHints'],
      personalityTraits: json['personalityTraits'],
    );
  }
}

class GameTiming {
  final int nightDuration;
  final int dayDiscussion;
  final int votingDuration;
  final int actionConfirmation;

  GameTiming({
    required this.nightDuration,
    required this.dayDiscussion,
    required this.votingDuration,
    required this.actionConfirmation,
  });

  factory GameTiming._fromYaml(YamlMap yaml) {
    return GameTiming(
      nightDuration: yaml['night_duration'],
      dayDiscussion: yaml['day_discussion'],
      votingDuration: yaml['voting_duration'],
      actionConfirmation: yaml['action_confirmation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nightDuration': nightDuration,
      'dayDiscussion': dayDiscussion,
      'votingDuration': votingDuration,
      'actionConfirmation': actionConfirmation,
    };
  }

  static GameTiming fromJson(Map<String, dynamic> json) {
    return GameTiming(
      nightDuration: json['nightDuration'],
      dayDiscussion: json['dayDiscussion'],
      votingDuration: json['votingDuration'],
      actionConfirmation: json['actionConfirmation'],
    );
  }
}

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
    final displayYaml = yaml['display'] as YamlMap;

    return UIConfig(
      consoleWidth: yaml['console_width'],
      enableColors: yaml['enable_colors'],
      enableAnimations: yaml['enable_animations'],
      showDebugInfo: yaml['show_debug_info'],
      logLevel: yaml['log_level'],
      display: DisplaySettings._fromYaml(displayYaml),
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
      showPlayerStatus: yaml['show_player_status'],
      showGameState: yaml['show_game_state'],
      showActionHistory: yaml['show_action_history'],
      showStatistics: yaml['show_statistics'],
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
      level: yaml['level'],
      enableConsole: yaml['enable_console'],
      enableFile: yaml['enable_file'],
      maxLogSizeMb: yaml['max_log_size_mb'],
      maxLogFiles: yaml['max_log_files'],
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
      enableDebugMode: yaml['enable_debug_mode'],
      enableTestMode: yaml['enable_test_mode'],
      mockLlmResponses: yaml['mock_llm_responses'],
      saveGameStates: yaml['save_game_states'],
      autoSaveInterval: yaml['auto_save_interval'],
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

class ActionOrderConfig {
  final String type;
  final String direction;

  ActionOrderConfig({
    required this.type,
    required this.direction,
  });

  factory ActionOrderConfig._fromYaml(YamlMap yaml) {
    return ActionOrderConfig(
      type: yaml['type'] ?? 'sequential',
      direction: yaml['direction'] ?? 'forward',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'direction': direction,
    };
  }

  static ActionOrderConfig fromJson(Map<String, dynamic> json) {
    return ActionOrderConfig(
      type: json['type'],
      direction: json['direction'],
    );
  }

  bool get isSequential => type == 'sequential';
  bool get isForward => direction == 'forward';
  bool get isReverse => direction == 'reverse';
}
