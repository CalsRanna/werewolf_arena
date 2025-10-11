import 'package:test/test.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/domain/value_objects/config_loader.dart';
import 'dart:io';

void main() {
  group('GameConfig Tests', () {
    test('GameConfig基本构造和属性访问', () {
      // 创建测试用的PlayerIntelligence
      final intelligence1 = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key-1',
        modelId: 'gpt-3.5-turbo',
      );

      final intelligence2 = PlayerIntelligence(
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: 'test-key-2',
        modelId: 'claude-3-sonnet',
      );

      // 创建GameConfig
      final config = GameConfig(
        playerIntelligences: [intelligence1, intelligence2],
        maxRetries: 5,
      );

      // 验证基本属性
      expect(config.playerIntelligences.length, equals(2));
      expect(config.maxRetries, equals(5));
      expect(
        config.playerIntelligences[0].baseUrl,
        equals('https://api.openai.com/v1'),
      );
      expect(config.playerIntelligences[1].apiKey, equals('test-key-2'));
    });

    test('getPlayerIntelligence方法测试', () {
      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        modelId: 'gpt-4',
      );

      final config = GameConfig(
        playerIntelligences: [intelligence],
        maxRetries: 3,
      );

      // 测试有效索引
      expect(config.getPlayerIntelligence(1), equals(intelligence));

      // 测试无效索引
      expect(config.getPlayerIntelligence(0), isNull); // 索引从1开始
      expect(config.getPlayerIntelligence(2), isNull); // 超出范围
      expect(config.getPlayerIntelligence(-1), isNull); // 负数索引
    });

    test('defaultIntelligence属性测试', () {
      final intelligence1 = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'default-key',
        modelId: 'gpt-3.5-turbo',
      );

      final intelligence2 = PlayerIntelligence(
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: 'second-key',
        modelId: 'claude-3-sonnet',
      );

      // 测试有智能配置的情况
      final configWithIntelligences = GameConfig(
        playerIntelligences: [intelligence1, intelligence2],
        maxRetries: 3,
      );
      expect(
        configWithIntelligences.defaultIntelligence,
        equals(intelligence1),
      );

      // 测试空智能配置的情况
      final emptyConfig = GameConfig(playerIntelligences: [], maxRetries: 3);
      expect(emptyConfig.defaultIntelligence, isNull);
    });
  });

  group('PlayerIntelligence Tests', () {
    test('PlayerIntelligence基本构造和属性', () {
      final intelligence = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test123',
        modelId: 'gpt-4-turbo',
      );

      expect(intelligence.baseUrl, equals('https://api.openai.com/v1'));
      expect(intelligence.apiKey, equals('sk-test123'));
      expect(intelligence.modelId, equals('gpt-4-turbo'));
    });

    test('PlayerIntelligence copyWith方法测试', () {
      final original = PlayerIntelligence(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'original-key',
        modelId: 'gpt-3.5-turbo',
      );

      // 测试部分更新
      final updated1 = original.copyWith(apiKey: 'new-key');
      expect(updated1.baseUrl, equals('https://api.openai.com/v1')); // 保持原值
      expect(updated1.apiKey, equals('new-key')); // 更新的值
      expect(updated1.modelId, equals('gpt-3.5-turbo')); // 保持原值

      // 测试多个字段更新
      final updated2 = original.copyWith(
        baseUrl: 'https://api.anthropic.com/v1',
        modelId: 'claude-3-opus',
      );
      expect(updated2.baseUrl, equals('https://api.anthropic.com/v1'));
      expect(updated2.apiKey, equals('original-key')); // 保持原值
      expect(updated2.modelId, equals('claude-3-opus'));

      // 测试不传参数（应该返回相同的值）
      final unchanged = original.copyWith();
      expect(unchanged.baseUrl, equals(original.baseUrl));
      expect(unchanged.apiKey, equals(original.apiKey));
      expect(unchanged.modelId, equals(original.modelId));
    });
  });

  group('ConfigLoader Tests', () {
    test('loadDefaultConfig静态方法测试', () async {
      // 测试加载默认配置
      final config = await ConfigLoader.loadDefaultConfig();

      expect(config, isNotNull);
      expect(config.playerIntelligences, isNotEmpty);
      expect(config.maxRetries, greaterThan(0));
      expect(config.defaultIntelligence, isNotNull);
    });

    test('配置验证逻辑测试', () {
      final loader = ConfigLoader();

      // 测试有效配置
      final validConfig = GameConfig(
        playerIntelligences: [
          PlayerIntelligence(
            baseUrl: 'https://api.openai.com/v1',
            apiKey: 'valid-key',
            modelId: 'gpt-3.5-turbo',
          ),
        ],
        maxRetries: 3,
      );

      final validErrors = loader.validateGameConfig(validConfig);
      expect(validErrors, isEmpty);

      // 测试无效配置 - 空智能列表
      final emptyIntelligenceConfig = GameConfig(
        playerIntelligences: [],
        maxRetries: 3,
      );

      final emptyErrors = loader.validateGameConfig(emptyIntelligenceConfig);
      expect(emptyErrors, contains('必须至少配置一个玩家智能'));

      // 测试无效配置 - 负数重试次数
      final negativeRetriesConfig = GameConfig(
        playerIntelligences: [
          PlayerIntelligence(
            baseUrl: 'https://api.openai.com/v1',
            apiKey: 'test-key',
            modelId: 'gpt-3.5-turbo',
          ),
        ],
        maxRetries: -1,
      );

      final negativeErrors = loader.validateGameConfig(negativeRetriesConfig);
      expect(negativeErrors, contains('最大重试次数不能为负数'));

      // 测试无效配置 - 空字段
      final emptyFieldsConfig = GameConfig(
        playerIntelligences: [
          PlayerIntelligence(
            baseUrl: '', // 空URL
            apiKey: '', // 空API Key
            modelId: '', // 空模型ID
          ),
        ],
        maxRetries: 3,
      );

      final emptyFieldsErrors = loader.validateGameConfig(emptyFieldsConfig);
      expect(emptyFieldsErrors, contains('玩家1配置: baseUrl不能为空'));
      expect(emptyFieldsErrors, contains('玩家1配置: apiKey不能为空'));
      expect(emptyFieldsErrors, contains('玩家1配置: modelId不能为空'));

      // 测试无效配置 - 无效URL格式
      final invalidUrlConfig = GameConfig(
        playerIntelligences: [
          PlayerIntelligence(
            baseUrl: 'not-a-valid-url',
            apiKey: 'test-key',
            modelId: 'gpt-3.5-turbo',
          ),
        ],
        maxRetries: 3,
      );

      final invalidUrlErrors = loader.validateGameConfig(invalidUrlConfig);
      expect(invalidUrlErrors, contains('玩家1配置: baseUrl格式无效'));
    });

    test('示例配置YAML生成测试', () {
      final loader = ConfigLoader();
      final sampleYaml = loader.generateSampleConfigYaml();

      expect(sampleYaml, isNotEmpty);
      expect(sampleYaml, contains('default_llm'));
      expect(sampleYaml, contains('player_models'));
      expect(sampleYaml, contains('gpt-3.5-turbo'));
      expect(sampleYaml, contains('max_retries'));
    });

    test('loadFromFile静态方法测试', () async {
      // 创建临时配置文件
      final tempDir = Directory.systemTemp.createTempSync('werewolf_test');
      final configFile = File('${tempDir.path}/test_config.yaml');

      // 写入测试配置
      await configFile.writeAsString('''
default_llm:
  model: "gpt-4"
  api_key: "test-api-key"
  base_url: "https://api.openai.com/v1"
  max_retries: 5

player_models:
  "2":
    model: "claude-3-sonnet-20240229"
    api_key: "test-claude-key"
    base_url: "https://api.anthropic.com/v1"
''');

      try {
        // 测试从文件加载
        final config = await ConfigLoader.loadFromFile(configFile.path);

        expect(config, isNotNull);
        expect(config.maxRetries, equals(5));
        expect(config.playerIntelligences.length, equals(2));

        // 验证默认配置
        final defaultIntelligence = config.defaultIntelligence!;
        expect(defaultIntelligence.modelId, equals('gpt-4'));
        expect(defaultIntelligence.apiKey, equals('test-api-key'));
        expect(
          defaultIntelligence.baseUrl,
          equals('https://api.openai.com/v1'),
        );

        // 验证第二个玩家配置
        final secondIntelligence = config.playerIntelligences[1];
        expect(secondIntelligence.modelId, equals('claude-3-sonnet-20240229'));
        expect(secondIntelligence.apiKey, equals('test-claude-key'));
        expect(
          secondIntelligence.baseUrl,
          equals('https://api.anthropic.com/v1'),
        );
      } finally {
        // 清理临时文件
        tempDir.deleteSync(recursive: true);
      }
    });

    test('从不存在的文件加载应返回默认配置', () async {
      final config = await ConfigLoader.loadFromFile('/non/existent/path.yaml');

      expect(config, isNotNull);
      expect(config.playerIntelligences, isNotEmpty);
      expect(config.maxRetries, equals(3)); // 默认值
    });
  });
}
