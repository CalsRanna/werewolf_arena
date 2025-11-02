import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:werewolf_arena/console/console_game_ui.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:yaml/yaml.dart';

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
      await file.parent.create(recursive: true);
      final defaultContent = _generateSampleConfigYaml();
      await file.writeAsString(defaultContent);
    } catch (e) {
      ConsoleGameUI.instance.printLine('创建默认配置文件失败: $e');
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

    final defaultLLM = yaml['default_llm'] as YamlMap;
    final defaultIntelligence = _parsePlayerIntelligenceFromYaml(defaultLLM);

    final playerModels = yaml['player_models'] as YamlList?;
    if (playerModels != null && playerModels.isNotEmpty) {
      for (var i = 0; i < 12; i++) {
        final model = playerModels[i % playerModels.length];
        final intelligence = defaultIntelligence.copyWith(modelId: model);
        playerIntelligences.add(intelligence);
      }
    } else {
      for (var i = 0; i < 12; i++) {
        playerIntelligences.add(defaultIntelligence);
      }
    }

    final maxRetries = (defaultLLM['max_retries'] as int?) ?? 3;

    final fastModelId = yaml['fast_model_id'] as String?;

    return GameConfig(
      playerIntelligences: playerIntelligences,
      maxRetries: maxRetries,
      fastModelId: fastModelId,
    );
  }

  PlayerIntelligence _parsePlayerIntelligenceFromYaml(YamlMap yaml) {
    String apiKey = yaml['api_key'] as String? ?? '';
    if (apiKey.isEmpty) {
      try {
        apiKey = Platform.environment['OPENAI_API_KEY'] ?? '';
      } catch (e) {
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
