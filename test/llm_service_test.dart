import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import '../lib/llm/llm_service.dart';
import '../lib/player/player.dart';
import '../lib/game/game_state.dart';
import '../lib/player/role.dart';

class MockGameState extends Mock implements GameState {}

class MockPlayer extends Mock implements Player {}

void main() {
  group('OpenAI Service Retry Tests', () {
    late OpenAIService service;
    late MockPlayer mockPlayer;
    late MockGameState mockState;

    setUp(() {
      service = OpenAIService(
        apiKey: 'test-key',
        model: 'gpt-3.5-turbo',
        retryConfig: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 100),
          backoffMultiplier: 2.0,
          maxDelay: Duration(seconds: 1),
        ),
      );

      mockPlayer = MockPlayer();
      mockState = MockGameState();

      // 设置基本的mock返回值
      when(() => mockPlayer.modelConfig).thenReturn(null);
      when(() => mockPlayer.name).thenReturn('Test Player');
      when(() => mockPlayer.playerId).thenReturn('test-player-id');
      when(() => mockState.currentPhase).thenReturn(GamePhase.day);
    });

    test('RetryConfig default values', () {
      const config = RetryConfig();
      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(seconds: 1)));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.maxDelay, equals(const Duration(seconds: 10)));
    });

    test('RetryConfig custom values', () {
      const config = RetryConfig(
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 500),
        backoffMultiplier: 1.5,
        maxDelay: Duration(seconds: 5),
      );
      expect(config.maxAttempts, equals(5));
      expect(config.initialDelay, equals(const Duration(milliseconds: 500)));
      expect(config.backoffMultiplier, equals(1.5));
      expect(config.maxDelay, equals(const Duration(seconds: 5)));
    });

    test('Retry configuration affects service creation', () {
      final serviceWithCustomRetry = OpenAIService(
        apiKey: 'test-key',
        retryConfig: const RetryConfig(
          maxAttempts: 5,
          initialDelay: Duration(milliseconds: 500),
        ),
      );

      expect(serviceWithCustomRetry.retryConfig.maxAttempts, equals(5));
      expect(serviceWithCustomRetry.retryConfig.initialDelay, equals(const Duration(milliseconds: 500)));
    });

    test('Service availability check', () {
      expect(service.isAvailable, isTrue);

      final emptyService = OpenAIService(apiKey: '');
      expect(emptyService.isAvailable, isFalse);
    });

    test('GenerateResponse with invalid API key should return error', () async {
      final invalidService = OpenAIService(
        apiKey: '',
        retryConfig: const RetryConfig(maxAttempts: 1), // 只尝试一次以加快测试
      );

      final response = await invalidService.generateResponse(
        systemPrompt: 'Test prompt',
        userPrompt: 'Test user prompt',
        context: {},
      );

      expect(response.isValid, isFalse);
      expect(response.content, contains('Error'));
      expect(response.errors, isNotEmpty);
    });
  });

  group('LLMResponse Tests', () {
    test('Success response creation', () {
      final response = LLMResponse.success(
        content: 'Test content',
        tokensUsed: 100,
        responseTimeMs: 500,
      );

      expect(response.isValid, isTrue);
      expect(response.content, equals('Test content'));
      expect(response.tokensUsed, equals(100));
      expect(response.responseTimeMs, equals(500));
      expect(response.errors, isEmpty);
    });

    test('Error response creation', () {
      final response = LLMResponse.error(
        content: 'Error occurred',
        errors: ['Network error', 'Invalid API key'],
      );

      expect(response.isValid, isFalse);
      expect(response.content, equals('Error occurred'));
      expect(response.errors, equals(['Network error', 'Invalid API key']));
    });

    test('toString method', () {
      final successResponse = LLMResponse.success(
        content: 'Test',
        targets: [MockPlayer()],
        statement: 'Test statement',
      );

      final result = successResponse.toString();
      expect(result, contains('isValid: true'));
      expect(result, contains('targets: 1'));
      expect(result, contains('statement: true'));
    });
  });
}