import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../game/game_state.dart';
import '../llm/json_cleaner.dart';
import '../player/player.dart';
import '../utils/logger_util.dart';

/// LLM response
class LLMResponse {
  LLMResponse({
    required this.content,
    required this.parsedData,
    required this.targets,
    required this.statement,
    required this.isValid,
    required this.errors,
    required this.tokensUsed,
    required this.responseTimeMs,
  });

  factory LLMResponse.success({
    required String content,
    Map<String, dynamic> parsedData = const {},
    List<Player> targets = const [],
    String statement = '',
    int tokensUsed = 0,
    int responseTimeMs = 0,
  }) {
    return LLMResponse(
      content: content,
      parsedData: parsedData,
      targets: targets,
      statement: statement,
      isValid: true,
      errors: [],
      tokensUsed: tokensUsed,
      responseTimeMs: responseTimeMs,
    );
  }

  factory LLMResponse.error({
    required String content,
    List<String> errors = const [],
    int tokensUsed = 0,
    int responseTimeMs = 0,
  }) {
    return LLMResponse(
      content: content,
      parsedData: {},
      targets: [],
      statement: '',
      isValid: false,
      errors: errors,
      tokensUsed: tokensUsed,
      responseTimeMs: responseTimeMs,
    );
  }
  final String content;
  final Map<String, dynamic> parsedData;
  final List<Player> targets;
  final String statement;
  final bool isValid;
  final List<String> errors;
  final int tokensUsed;
  final int responseTimeMs;

  @override
  String toString() {
    return 'LLMResponse(isValid: $isValid, targets: ${targets.length}, statement: ${statement.isNotEmpty})';
  }
}

/// LLM service interface
abstract class LLMService {
  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
  });

  Future<LLMResponse> generateAction({
    required Player player,
    required GameState state,
    required String rolePrompt,
  });

  Future<LLMResponse> generateStatement({
    required Player player,
    required GameState state,
    required String context,
    required String prompt,
  });

  bool get isAvailable;
}

/// OpenAI API implementation
/// Note: openai_dart dependency is available but the original HTTP implementation is kept for stability
class OpenAIService implements LLMService {
  OpenAIService({
    required this.apiKey,
    this.model = 'gpt-3.5-turbo',
    http.Client? client,
    ResponseCache? cache,
  })  : client = client ?? http.Client(),
        cache = cache ?? ResponseCache();
  final String apiKey;
  final String model;
  final http.Client client;
  final ResponseCache cache;

  // Instance-specific model and API key that can be updated per request
  String? _instanceModel;
  String? _instanceApiKey;

  /// Create service from player model config
  factory OpenAIService.fromPlayerConfig(PlayerModelConfig config) {
    return OpenAIService(
      apiKey: config.apiKey,
      model: config.model,
    );
  }

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  @override
  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    String? overrideModel,
    String? overrideApiKey,
  }) async {
    final startTime = DateTime.now();
    final cacheKey = _generateCacheKey(systemPrompt, userPrompt, context);

    // Try cache first
    final cachedResponse = cache.get(cacheKey);
    if (cachedResponse != null) {
      LoggerUtil.instance.d('📦 Using cached response');
      LoggerUtil.instance.d('Cache key: $cacheKey');
      LoggerUtil.instance.d(
          'Cached content: ${cachedResponse.length > 200 ? "${cachedResponse.substring(0, 200)}..." : cachedResponse}');

      return LLMResponse.success(
        content: cachedResponse,
        responseTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    }

    try {
      final apiResponse = await _makeAPIRequest(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
        overrideModel: overrideModel,
        overrideApiKey: overrideApiKey,
      );

      final responseTimeMs =
          DateTime.now().difference(startTime).inMilliseconds;

      // Convert API response to LLMResponse
      final response = LLMResponse.success(
        content: apiResponse['content'] ?? '',
        tokensUsed: apiResponse['tokensUsed'] ?? 0,
        responseTimeMs: responseTimeMs,
      );

      // Cache successful response
      if (response.isValid) {
        cache.put(cacheKey, response.content);
        LoggerUtil.instance.d('💾 Response cached with key: $cacheKey');
      }

      LoggerUtil.instance.d('🎯 LLM Response processed successfully');
      LoggerUtil.instance.d('Total response time: ${responseTimeMs}ms');
      LoggerUtil.instance.d('Response validity: ${response.isValid}');
      LoggerUtil.instance
          .d('Response content length: ${response.content.length}');

      return response;
    } catch (e) {
      LoggerUtil.instance.d('❌ LLM API Exception occurred');
      LoggerUtil.instance.d('Exception type: ${e.runtimeType}');
      LoggerUtil.instance.d('Exception details: $e');
      LoggerUtil.instance.d(
          'Total time before failure: ${DateTime.now().difference(startTime).inMilliseconds}ms');

      return LLMResponse.error(
        content: 'Error: $e',
        errors: [e.toString()],
        responseTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  @override
  Future<LLMResponse> generateAction({
    required Player player,
    required GameState state,
    required String rolePrompt,
  }) async {
    // rolePrompt已经包含了所有需要的信息,直接使用
    // 不需要额外的context构建

    // Use player's model config if available
    String? overrideModel;
    String? overrideApiKey;

    if (player.modelConfig != null) {
      overrideModel = player.modelConfig!.model;
      overrideApiKey = player.modelConfig!.apiKey;
    }

    final response = await generateResponse(
      systemPrompt: rolePrompt,
      userPrompt: '', // rolePrompt已经包含完整prompt
      context: {'phase': state.currentPhase.name},
      overrideModel: overrideModel,
      overrideApiKey: overrideApiKey,
    );

    if (response.isValid) {
      return await _parseActionResponse(response, player, state);
    }

    return response;
  }

  @override
  Future<LLMResponse> generateStatement({
    required Player player,
    required GameState state,
    required String context,
    required String prompt,
  }) async {
    final gameContext = _buildContext(player, state);

    final userPrompt = '''
Current game state:
$gameContext

Current situation:
$context
''';

    // Use player's model config if available
    String? overrideModel;
    String? overrideApiKey;

    if (player.modelConfig != null) {
      overrideModel = player.modelConfig!.model;
      overrideApiKey = player.modelConfig!.apiKey;
    }

    final response = await generateResponse(
      systemPrompt: prompt,
      userPrompt: userPrompt,
      context: {'game_state': gameContext},
      overrideModel: overrideModel,
      overrideApiKey: overrideApiKey,
    );

    if (response.isValid) {
      return LLMResponse.success(
        content: response.content,
        statement: response.content.trim(),
        parsedData: response.parsedData,
        responseTimeMs: response.responseTimeMs,
      );
    }

    return response;
  }

  Future<Map<String, dynamic>> _makeAPIRequest({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    String? overrideModel,
    String? overrideApiKey,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    // Use override values if provided, otherwise use instance defaults
    final effectiveModel = overrideModel ?? _instanceModel ?? model;
    final effectiveApiKey = overrideApiKey ?? _instanceApiKey ?? apiKey;

    final headers = {
      'Authorization': 'Bearer $effectiveApiKey',
      'Content-Type': 'application/json',
    };

    // 如果userPrompt为空,将systemPrompt作为用户消息
    final messages = userPrompt.isEmpty
        ? [
            {
              'role': 'user',
              'content': systemPrompt,
            },
          ]
        : [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userPrompt,
            },
          ];

    final body = jsonEncode({
      'model': effectiveModel,
      'messages': messages,
    });

    final response = await client
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 60));

    // Log request details
    LoggerUtil.instance.d('=== LLM API Request ===');
    LoggerUtil.instance.d('URL: $url');
    LoggerUtil.instance.d('Model: $effectiveModel');
    LoggerUtil.instance.d('Request body: $body');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final tokensUsed = data['usage']['total_tokens'] ?? 0;

      LoggerUtil.instance.d('✅ LLM API Success');
      LoggerUtil.instance.d('Response status: ${response.statusCode}');
      LoggerUtil.instance.d('Response body: ${response.body}');
      LoggerUtil.instance.d('Tokens used: $tokensUsed');
      LoggerUtil.instance.d(
          'Content preview: ${content.length > 200 ? content.substring(0, 200) + "..." : content}');

      return {
        'content': content,
        'tokensUsed': tokensUsed,
        'success': true,
      };
    } else {
      final error = jsonDecode(response.body);
      final errorMessage = error['error']['message'] ?? 'Unknown error';

      LoggerUtil.instance.d('❌ LLM API Error');
      LoggerUtil.instance.d('Response status: ${response.statusCode}');
      LoggerUtil.instance.d('Response body: ${response.body}');
      LoggerUtil.instance.d('Error message: $errorMessage');

      throw Exception('OpenAI API error: $errorMessage');
    }
  }

  Future<LLMResponse> _parseActionResponse(
    LLMResponse response,
    Player player,
    GameState state,
  ) async {
    LoggerUtil.instance
        .d('Attempting to parse action response from: ${response.content}');

    // Try multiple parsing strategies in order
    Map<String, dynamic>? jsonData;
    String parsingStrategy = '';

    // Strategy 1: Direct JSON parsing after cleaning
    try {
      final cleanedContent = _extractJsonFromResponse(response.content);
      jsonData = jsonDecode(cleanedContent);
      parsingStrategy = 'direct parsing';
      LoggerUtil.instance.d('Strategy 1 (direct parsing) succeeded');
    } catch (e) {
      LoggerUtil.instance.d('Strategy 1 (direct parsing) failed: $e');
    }

    // Strategy 2: Enhanced JSON cleaner partial extraction
    if (jsonData == null) {
      try {
        jsonData = JsonCleaner.extractPartialJson(response.content);
        if (jsonData != null) {
          parsingStrategy = 'partial extraction';
          LoggerUtil.instance.d('Strategy 2 (partial extraction) succeeded');
        }
      } catch (e) {
        LoggerUtil.instance.d('Strategy 2 (partial extraction) failed: $e');
      }
    }

    // If all parsing strategies failed, return empty response
    if (jsonData == null) {
      LoggerUtil.instance
          .w('All parsing strategies failed for response: ${response.content}');
      return LLMResponse.success(
        content: response.content,
        parsedData: <String, dynamic>{},
        targets: <Player>[],
        statement: '',
        tokensUsed: response.tokensUsed,
        responseTimeMs: response.responseTimeMs,
      );
    }

    // Successfully parsed data, now process it
    LoggerUtil.instance.d(
        'Successfully parsed action response using $parsingStrategy: action=${jsonData['action']}, target=${jsonData['target']}');

    // 支持多种target字段名: target_id, target, 目标
    final targetId =
        jsonData['target_id'] ?? jsonData['target'] ?? jsonData['目标'];
    final statement = jsonData['statement'] ?? jsonData['陈述'] ?? '';
    final reasoning = jsonData['reasoning'] ?? jsonData['推理'] ?? '';

    final targets = <Player>[];
    if (targetId != null && targetId.toString().isNotEmpty) {
      // 首先尝试直接通过ID查找
      Player? target = state.getPlayerById(targetId.toString());

      // 如果找不到,尝试通过玩家名字查找(支持"3号玩家"这样的格式)
      if (target == null) {
        final targetStr = targetId.toString();
        for (final p in state.players) {
          if (p.name == targetStr || p.playerId == targetStr) {
            target = p;
            break;
          }
        }
      }

      // 如果还找不到，尝试通过数字匹配玩家名（支持 "5" -> "5号玩家"）
      if (target == null) {
        final targetStr = targetId.toString();
        // 检查是否是纯数字
        final numberMatch = RegExp(r'^\d+$').firstMatch(targetStr);
        if (numberMatch != null) {
          final playerName = '$targetStr号玩家';
          for (final p in state.players) {
            if (p.name == playerName) {
              target = p;
              break;
            }
          }
        }
      }

      if (target != null) {
        targets.add(target);
      } else {
        LoggerUtil.instance.w('Target not found: $targetId');
      }
    }

    // 存储reasoning到parsedData
    final parsedData = Map<String, dynamic>.from(jsonData);
    if (!parsedData.containsKey('reasoning') && reasoning.isNotEmpty) {
      parsedData['reasoning'] = reasoning;
    }

    return LLMResponse.success(
      content: response.content,
      parsedData: parsedData,
      targets: targets,
      statement: statement,
      tokensUsed: response.tokensUsed,
      responseTimeMs: response.responseTimeMs,
    );
  }

  /// Extract JSON from response content, handling markdown formatting and other issues
  String _extractJsonFromResponse(String content) {
    // Use the enhanced JSON cleaner
    final cleaned = JsonCleaner.extractJson(content);
    LoggerUtil.instance.d('Cleaned JSON: $cleaned');
    return cleaned;
  }

  String _buildContext(Player player, GameState state) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');

    return '''
Game Day ${state.dayNumber}
Current phase: ${state.currentPhase.displayName}
Alive players: ${alivePlayers.isNotEmpty ? alivePlayers : 'None'}
Dead players: ${deadPlayers.isNotEmpty ? deadPlayers : 'None'}
Your status: ${player.isAlive ? 'Alive' : 'Dead'}
Your role: ${player.role.name}
''';
  }

  String _generateCacheKey(
      String systemPrompt, String userPrompt, Map<String, dynamic> context) {
    final combined = '$systemPrompt|$userPrompt|${context.toString()}';
    return combined.hashCode.toRadixString(16);
  }

  void dispose() {
    client.close();
  }
}

/// Response cache
class ResponseCache {
  ResponseCache({
    this.maxAge = const Duration(minutes: 30),
    this.maxSize = 1000,
  });
  final Map<String, CacheEntry> _cache = {};
  final Duration maxAge;
  final int maxSize;

  String? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > maxAge) {
      _cache.remove(key);
      return null;
    }

    return entry.response;
  }

  void put(String key, String response) {
    if (_cache.length >= maxSize) {
      _evictOldest();
    }

    _cache[key] = CacheEntry(
      response: response,
      timestamp: DateTime.now(),
    );
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;

    final oldest = _cache.entries.reduce(
        (a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b);

    _cache.remove(oldest.key);
  }

  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
}

class CacheEntry {
  CacheEntry({
    required this.response,
    required this.timestamp,
  });
  final String response;
  final DateTime timestamp;
}
