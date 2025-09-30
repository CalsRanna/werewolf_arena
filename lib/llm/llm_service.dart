import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../game/game_state.dart';
import '../game/game_action.dart';
import '../player/player.dart';
import '../utils/game_logger.dart';

/// LLM response
class LLMResponse {
  LLMResponse({
    required this.content,
    required this.parsedData,
    required this.actions,
    required this.statement,
    required this.isValid,
    required this.errors,
    required this.tokensUsed,
    required this.responseTimeMs,
  });

  factory LLMResponse.success({
    required String content,
    Map<String, dynamic> parsedData = const {},
    List<GameAction> actions = const [],
    String statement = '',
    int tokensUsed = 0,
    int responseTimeMs = 0,
  }) {
    return LLMResponse(
      content: content,
      parsedData: parsedData,
      actions: actions,
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
      actions: [],
      statement: '',
      isValid: false,
      errors: errors,
      tokensUsed: tokensUsed,
      responseTimeMs: responseTimeMs,
    );
  }
  final String content;
  final Map<String, dynamic> parsedData;
  final List<GameAction> actions;
  final String statement;
  final bool isValid;
  final List<String> errors;
  final int tokensUsed;
  final int responseTimeMs;

  @override
  String toString() {
    return 'LLMResponse(isValid: $isValid, actions: ${actions.length}, statement: ${statement.isNotEmpty})';
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
    required this.logger,
    this.model = 'gpt-3.5-turbo',
    http.Client? client,
    ResponseCache? cache,
  })  : client = client ?? http.Client(),
        cache = cache ?? ResponseCache();
  final String apiKey;
  final String model;
  final GameLogger logger;
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
      logger.llmError(e.toString());
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
    final context = _buildContext(player, state);
    final availableActions = player.getAvailableActions(state);

    final userPrompt = '''
Current game state:
$context

Your role: ${player.role.name}
Available actions: ${_formatActions(availableActions)}

Please choose your action and return in JSON format:
{
  "action": "action type",
  "target": "target player ID (optional)",
  "reasoning": "reasoning process",
  "statement": "public statement"
}

Make the most appropriate choice based on your role and current situation.
''';

    final response = await generateResponse(
      systemPrompt: rolePrompt,
      userPrompt: userPrompt,
      context: {'game_state': context},
      temperature: 0.7,
      maxTokens: 500,
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

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': userPrompt,
        },
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await client.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final tokensUsed = data['usage']['total_tokens'] ?? 0;

      logger.llmCall(model, tokensUsed, 0);

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
      final jsonData = jsonDecode(response.content);

      if (!jsonData.containsKey('action')) {
        return LLMResponse.error(
          content: response.content,
          errors: ['Missing action field'],
          tokensUsed: response.tokensUsed,
          responseTimeMs: response.responseTimeMs,
        );
      }

      final actionType = _parseActionType(jsonData['action']);
      final targetId = jsonData['target'];
      final statement = jsonData['statement'] ?? '';

      Player? target;
      if (targetId != null) {
        target = state.getPlayerById(targetId);
      }

      final action = _buildAction(actionType, player, target, jsonData);

      return LLMResponse.success(
        content: response.content,
        parsedData: jsonData,
        actions: [action],
        statement: statement,
        tokensUsed: response.tokensUsed,
        responseTimeMs: response.responseTimeMs,
      );
    } catch (e) {
      return LLMResponse.error(
        content: response.content,
        errors: ['Parse error: $e'],
        tokensUsed: response.tokensUsed,
        responseTimeMs: response.responseTimeMs,
      );
    }
  }

  ActionType _parseActionType(String actionString) {
    switch (actionString.toLowerCase()) {
      case 'kill':
        return ActionType.kill;
      case 'protect':
        return ActionType.protect;
      case 'investigate':
        return ActionType.investigate;
      case 'heal':
        return ActionType.heal;
      case 'poison':
        return ActionType.poison;
      case 'vote':
        return ActionType.vote;
      case 'speak':
        return ActionType.speak;
      default:
        throw Exception('Unknown action type: $actionString');
    }
  }

  GameAction _buildAction(
    ActionType type,
    Player actor,
    Player? target,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case ActionType.kill:
        return KillAction(actor: actor, target: target!);
      case ActionType.investigate:
        return InvestigateAction(actor: actor, target: target!);
      case ActionType.heal:
        return HealAction(actor: actor, target: target!);
      case ActionType.poison:
        return PoisonAction(actor: actor, target: target!);
      case ActionType.vote:
        return VoteAction(actor: actor, target: target!);
      case ActionType.speak:
        return SpeakAction(actor: actor, message: data['statement'] ?? '');
      default:
        throw Exception('Action type not implemented: $type');
    }
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

  String _formatActions(List<GameAction> actions) {
    if (actions.isEmpty) return 'No available actions';

    return actions.map((action) {
      final targetPart =
          action.target != null ? ' -> ${action.target!.name}' : '';
      return '${action.type.name}$targetPart';
    }).join(', ');
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
