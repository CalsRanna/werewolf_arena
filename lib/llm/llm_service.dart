import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../game/game_state.dart';
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
    double temperature = 0.7,
    int maxTokens = 1000,
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

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  @override
  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    final startTime = DateTime.now();
    final cacheKey = _generateCacheKey(systemPrompt, userPrompt, context);

    // Try cache first
    final cachedResponse = cache.get(cacheKey);
    if (cachedResponse != null) {
      return LLMResponse.success(
        content: cachedResponse,
        responseTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    }

    try {
      final apiResponse = await _makeAPIRequest(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        context: context,
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
      }

      return response;
    } catch (e) {
      LoggerUtil.instance.w(e.toString());
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

    final response = await generateResponse(
      systemPrompt: rolePrompt,
      userPrompt: '', // rolePrompt已经包含完整prompt
      context: {'phase': state.currentPhase.name},
      temperature: 0.7,
      maxTokens: 1000, // 增加token限制以支持更详细的推理
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

Please make appropriate statements based on your role and personality. Maintain character consistency.
''';

    final response = await generateResponse(
      systemPrompt: prompt,
      userPrompt: userPrompt,
      context: {'game_state': gameContext},
      temperature: 0.8,
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
    required double temperature,
    required int maxTokens,
    required Map<String, dynamic> context,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final headers = {
      'Authorization': 'Bearer $apiKey',
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
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await client.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final tokensUsed = data['usage']['total_tokens'] ?? 0;

      LoggerUtil.instance.d('LLM call: model=$model, tokens=$tokensUsed, duration=0ms');

      return {
        'content': content,
        'tokensUsed': tokensUsed,
        'success': true,
      };
    } else {
      final error = jsonDecode(response.body);
      final errorMessage = error['error']['message'] ?? 'Unknown error';
      throw Exception('OpenAI API error: $errorMessage');
    }
  }

  Future<LLMResponse> _parseActionResponse(
    LLMResponse response,
    Player player,
    GameState state,
  ) async {
    try {
      // Clean up the response content to extract pure JSON
      final cleanedContent = _extractJsonFromResponse(response.content);
      final jsonData = jsonDecode(cleanedContent);

      // 支持多种target字段名: target_id, target, 目标
      final targetId = jsonData['target_id'] ?? jsonData['target'] ?? jsonData['目标'];
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
    } catch (e) {
      LoggerUtil.instance.e('Failed to parse action response: $e');
      LoggerUtil.instance.e('Response content: ${response.content}');

      // Try to extract any useful information even if JSON parsing fails
      return _handleParseError(response, e);
    }
  }

  /// Extract JSON from response content, handling markdown formatting and other issues
  String _extractJsonFromResponse(String content) {
    // Remove markdown code blocks
    String cleaned = content;

    // Remove ```json and ``` markers
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*'), '');

    // Remove any leading/trailing whitespace
    cleaned = cleaned.trim();

    // Try to find JSON object within the text
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');

    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
    }

    LoggerUtil.instance.d('Cleaned JSON: $cleaned');
    return cleaned;
  }

  /// Handle parsing errors with fallback strategies
  LLMResponse _handleParseError(LLMResponse response, dynamic error) {
    LoggerUtil.instance.w('Attempting to extract information from malformed response');

    final content = response.content.toLowerCase();
    final parsedData = <String, dynamic>{};
    final targets = <Player>[];
    String statement = '';

    // Try to extract basic information using regex patterns
    try {
      // Look for action type
      final actionMatch = RegExp(r'"action"\s*:\s*"([^"]+)"').firstMatch(content);
      if (actionMatch != null) {
        parsedData['action'] = actionMatch.group(1);
      }

      // Look for target
      final targetMatch = RegExp(r'"target"\s*:\s*"([^"]+)"').firstMatch(content);
      if (targetMatch != null) {
        parsedData['target'] = targetMatch.group(1);
      }

      // Look for reasoning
      final reasoningMatch = RegExp(r'"reasoning"\s*:\s*"([^"]+)"').firstMatch(content);
      if (reasoningMatch != null) {
        parsedData['reasoning'] = reasoningMatch.group(1);
      }

      // Look for statement
      final statementMatch = RegExp(r'"statement"\s*:\s*"([^"]+)"').firstMatch(content);
      if (statementMatch != null) {
        statement = statementMatch.group(1) ?? '';
        parsedData['statement'] = statement;
      }

      LoggerUtil.instance.i('Extracted partial data from malformed JSON: $parsedData');
    } catch (e) {
      LoggerUtil.instance.e('Failed to extract any data from malformed response: $e');
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
