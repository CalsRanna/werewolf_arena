import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:yaml/yaml.dart';

import 'console_game_ui.dart';

/// Console端配置加载器 - 从可执行文件所在目录加载 YAML 文件
class ConsoleGameConfigLoader {
  Future<GameConfig> loadGameConfig() async {
    var currentDirectory = Directory.current;
    try {
      final filePath = path.join(currentDirectory.path, 'werewolf_config.yaml');
      final file = File(filePath);
      if (!file.existsSync()) {
        ConsoleGameUI.instance.printLine('配置文件不存在: $filePath');
        await _createDefaultConfigFile(filePath);
        ConsoleGameUI.instance.printLine('已自动创建默认配置文件: $filePath');
      }

      final yamlString = file.readAsStringSync();
      final yamlMap = loadYaml(yamlString) as YamlMap;

      return _parseGameConfigFromYaml(yamlMap);
    } catch (e) {
      ConsoleGameUI.instance.printLine('配置文件加载失败: $e，使用默认配置');
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
      ConsoleGameUI.instance.printLine('创建默认配置文件失败: $e');
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
  max_retries: 10

# 快速模型配置（用于简单推理任务的性能优化）
# 这个模型会用于：剧本选择、面具选择、自我反思等简单步骤
# 推荐使用小而快的模型：gpt-4o-mini, claude-3-5-haiku-20241022, deepseek/deepseek-chat
# 如果不配置，则所有步骤都使用player_models中的模型
fast_model_id: gpt-4o-mini

# 玩家专属模型配置
player_models:
  - deepseek/deepseek-v3.2-exp

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

    // 解析玩家专属配置
    final playerModels = yaml['player_models'] as YamlList?;
    if (playerModels != null && playerModels.isNotEmpty) {
      // 为12个玩家循环使用player_models中的模型
      for (var i = 0; i < 12; i++) {
        final model = playerModels[i % playerModels.length];
        final intelligence = defaultIntelligence.copyWith(modelId: model);
        playerIntelligences.add(intelligence);
      }
    } else {
      // 如果没有player_models配置，所有玩家都使用默认配置
      for (var i = 0; i < 12; i++) {
        playerIntelligences.add(defaultIntelligence);
      }
    }

    // 解析maxRetries
    final maxRetries = (defaultLLM['max_retries'] as int?) ?? 3;

    // 解析fast_model_id（性能优化配置，可选）
    final fastModelId = yaml['fast_model_id'] as String?;

    return GameConfig(
      playerIntelligences: playerIntelligences,
      maxRetries: maxRetries,
      fastModelId: fastModelId,
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
