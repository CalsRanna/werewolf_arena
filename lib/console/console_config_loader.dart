import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:yaml/yaml.dart';

import 'console_output.dart';

/// Console端配置加载器 - 从可执行文件所在目录加载 YAML 文件
class ConsoleConfigLoader {
  Future<GameConfig> loadGameConfig() async {
    var currentDirectory = Directory.current;
    try {
      final filePath = path.join(currentDirectory.path, 'werewolf_config.yaml');
      final file = File(filePath);
      if (!file.existsSync()) {
        ConsoleGameOutput.instance.printLine('配置文件不存在: $filePath');
        await _createDefaultConfigFile(filePath);
        ConsoleGameOutput.instance.printLine('已自动创建默认配置文件: $filePath');
      }

      final yamlString = file.readAsStringSync();
      final yamlMap = loadYaml(yamlString) as YamlMap;

      return _parseGameConfigFromYaml(yamlMap);
    } catch (e) {
      ConsoleGameOutput.instance.printLine('配置文件加载失败: $e，使用默认配置');
      return _createDefaultGameConfig();
    }
  }

  Future<void> _createDefaultConfigFile(String configPath) async {
    try {
      final file = File(configPath);

      // 确保父目录存在
      await file.parent.create(recursive: true);

      // 生成默认配置内容
      final defaultContent = _generateSampleConfigYaml();

      // 写入文件
      await file.writeAsString(defaultContent);
    } catch (e) {
      ConsoleGameOutput.instance.printLine('创建默认配置文件失败: $e');
      // 如果创建失败，继续使用内存中的默认配置
    }
  }

  GameConfig _createDefaultGameConfig() {
    return GameConfig(
      playerIntelligences: [_createDefaultPlayerIntelligence()],
      maxRetries: 3,
    );
  }

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

  String _generateSampleConfigYaml() {
    return '''
# Werewolf Arena 游戏配置文件
# 
# 此文件定义了游戏运行所需的基本配置

# 默认LLM配置
default_llm:
  api_key: YOUR_KEY_HERE
  base_url: "https://api.openai.com/v1"
  max_retries: 3

# 玩家专属模型配置
player_models:
  - gpt-3.5-turbo

# 日志配置（暂时保留兼容性，未来可能移除）
logging:
  level: "info"
  enable_console: true
  enable_file: true
  backup_count: 5
''';
  }

  GameConfig _parseGameConfigFromYaml(YamlMap yaml) {
    final playerIntelligences = <PlayerIntelligence>[];

    // 解析默认LLM配置
    final defaultLLM = yaml['default_llm'] as YamlMap;
    final defaultIntelligence = _parsePlayerIntelligenceFromYaml(defaultLLM);
    playerIntelligences.add(defaultIntelligence);

    // 解析玩家专属配置
    final playerModels = yaml['player_models'] as YamlList?;
    if (playerModels != null) {
      for (final model in playerModels) {
        final intelligence = defaultIntelligence.copyWith(modelId: model);
        playerIntelligences.add(intelligence);
      }
    }

    // 如果没有任何配置，添加默认配置
    if (playerIntelligences.isEmpty) {
      playerIntelligences.add(_createDefaultPlayerIntelligence());
    }

    // 解析maxRetries
    final maxRetries = (defaultLLM['max_retries'] as int?) ?? 3;

    return GameConfig(
      playerIntelligences: playerIntelligences,
      maxRetries: maxRetries,
    );
  }

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
}
