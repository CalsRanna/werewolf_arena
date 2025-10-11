import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';

/// 配置加载工具
///
/// 负责从YAML配置文件转换为GameConfig对象
class ConfigLoader {
  final String? customConfigDir;

  ConfigLoader({this.customConfigDir});

  String get _configDir {
    if (customConfigDir != null) {
      return customConfigDir!;
    }
    // 从当前可执行文件目录加载
    return Directory.current.path;
  }

  /// 从YAML文件加载GameConfig
  ///
  /// [configPath] 可选的配置文件路径，如果不提供则使用默认路径
  /// 返回GameConfig对象，如果加载失败则返回默认配置
  Future<GameConfig> loadGameConfig([String? configPath]) async {
    try {
      final actualConfigPath =
          configPath ?? path.join(_configDir, 'werewolf_config.yaml');

      final file = File(actualConfigPath);
      if (!file.existsSync()) {
        print('配置文件不存在: $actualConfigPath，使用默认配置');
        return _createDefaultGameConfig();
      }

      final yamlString = file.readAsStringSync();
      final yamlMap = loadYaml(yamlString) as YamlMap;

      return _parseGameConfigFromYaml(yamlMap);
    } catch (e) {
      print('配置文件加载失败: $e，使用默认配置');
      return _createDefaultGameConfig();
    }
  }

  /// 从YamlMap解析GameConfig
  GameConfig _parseGameConfigFromYaml(YamlMap yaml) {
    final playerIntelligences = <PlayerIntelligence>[];

    // 解析默认LLM配置
    final defaultLLM = yaml['default_llm'] as YamlMap?;
    if (defaultLLM != null) {
      final defaultIntelligence = _parsePlayerIntelligenceFromYaml(defaultLLM);
      playerIntelligences.add(defaultIntelligence);
    }

    // 解析玩家专属配置
    final playerModels = yaml['player_models'] as YamlMap?;
    if (playerModels != null) {
      for (final entry in playerModels.entries) {
        final playerConfig = entry.value as YamlMap;
        final intelligence = _parsePlayerIntelligenceFromYaml(playerConfig);
        playerIntelligences.add(intelligence);
      }
    }

    // 如果没有任何配置，添加默认配置
    if (playerIntelligences.isEmpty) {
      playerIntelligences.add(_createDefaultPlayerIntelligence());
    }

    // 解析maxRetries
    final maxRetries = (defaultLLM?['max_retries'] as int?) ?? 3;

    return GameConfig(
      playerIntelligences: playerIntelligences,
      maxRetries: maxRetries,
    );
  }

  /// 从YamlMap解析PlayerIntelligence
  PlayerIntelligence _parsePlayerIntelligenceFromYaml(YamlMap yaml) {
    // 安全获取API key，优先从配置文件，然后尝试环境变量
    String apiKey = yaml['api_key'] as String? ?? '';
    if (apiKey.isEmpty) {
      try {
        apiKey = Platform.environment['OPENAI_API_KEY'] ?? '';
      } catch (e) {
        // Web平台不支持Platform.environment
        apiKey = '';
      }
    }

    return PlayerIntelligence(
      baseUrl: yaml['base_url'] as String? ?? 'https://api.openai.com/v1',
      apiKey: apiKey,
      modelId: yaml['model'] as String? ?? 'gpt-3.5-turbo',
    );
  }

  /// 创建默认GameConfig
  GameConfig _createDefaultGameConfig() {
    return GameConfig(
      playerIntelligences: [_createDefaultPlayerIntelligence()],
      maxRetries: 3,
    );
  }

  /// 创建默认PlayerIntelligence
  PlayerIntelligence _createDefaultPlayerIntelligence() {
    String apiKey = '';
    try {
      apiKey = Platform.environment['OPENAI_API_KEY'] ?? '';
    } catch (e) {
      // Web平台不支持Platform.environment
      apiKey = '';
    }

    return PlayerIntelligence(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: apiKey,
      modelId: 'gpt-3.5-turbo',
    );
  }

  /// 验证GameConfig配置
  ///
  /// 返回验证错误列表，如果为空表示配置有效
  List<String> validateGameConfig(GameConfig config) {
    final errors = <String>[];

    if (config.playerIntelligences.isEmpty) {
      errors.add('必须至少配置一个玩家智能');
    }

    if (config.maxRetries < 0) {
      errors.add('最大重试次数不能为负数');
    }

    // 验证每个玩家智能配置
    for (int i = 0; i < config.playerIntelligences.length; i++) {
      final intelligence = config.playerIntelligences[i];
      final prefix = '玩家${i + 1}配置';

      if (intelligence.baseUrl.isEmpty) {
        errors.add('$prefix: baseUrl不能为空');
      }

      if (intelligence.apiKey.isEmpty) {
        errors.add('$prefix: apiKey不能为空');
      }

      if (intelligence.modelId.isEmpty) {
        errors.add('$prefix: modelId不能为空');
      }

      // 验证baseUrl格式
      final uri = Uri.tryParse(intelligence.baseUrl);
      if (uri == null || !uri.hasAbsolutePath) {
        errors.add('$prefix: baseUrl格式无效');
      }
    }

    return errors;
  }

  /// 从文件加载配置（与loadGameConfig方法兼容）
  ///
  /// GameAssembler需要的方法接口
  static Future<GameConfig> loadFromFile(String configPath) async {
    final loader = ConfigLoader();
    return await loader.loadGameConfig(configPath);
  }

  /// 加载默认配置（与loadGameConfig方法兼容）
  ///
  /// GameAssembler需要的方法接口
  static Future<GameConfig> loadDefaultConfig() async {
    final loader = ConfigLoader();
    return await loader.loadGameConfig(); // 不传路径即为默认配置
  }

  /// 创建示例配置文件内容
  ///
  /// 用于生成示例配置文件供用户参考
  String generateSampleConfigYaml() {
    return '''
# Werewolf Arena 游戏配置文件
# 
# 此文件定义了游戏运行所需的基本配置

# 默认LLM配置
default_llm:
  model: "gpt-3.5-turbo"
  api_key: "\${OPENAI_API_KEY}"  # 从环境变量读取，或直接填写
  base_url: "https://api.openai.com/v1"
  max_retries: 3

# 玩家专属模型配置（可选）
# 如果不配置，所有玩家将使用默认配置
player_models:
  "2":  # 2号玩家使用Claude
    model: "claude-3-sonnet-20240229"
    api_key: "\${ANTHROPIC_API_KEY}"
    base_url: "https://api.anthropic.com/v1"
  "3":  # 3号玩家使用不同的GPT模型
    model: "gpt-4"
    api_key: "\${OPENAI_API_KEY}"
    base_url: "https://api.openai.com/v1"

# 日志配置（暂时保留兼容性，未来可能移除）
logging:
  level: "info"
  enable_console: true
  enable_file: true
  backup_count: 5
''';
  }
}
