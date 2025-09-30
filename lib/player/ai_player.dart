import 'dart:async';
import 'player.dart';
import 'role.dart';
import '../game/game_state.dart';
import '../game/game_action.dart';
import '../llm/llm_service.dart';
import '../llm/prompt_manager.dart';
import '../utils/random_helper.dart';
import '../utils/logger_util.dart';

/// AI personality traits
class Personality {
  final double aggressiveness; // Aggressiveness 0-1
  final double logicThinking; // Logical thinking 0-1
  final double cooperativeness; // Cooperativeness 0-1
  final double honesty; // Honesty 0-1
  final double expressiveness; // Expressiveness 0-1

  Personality({
    required this.aggressiveness,
    required this.logicThinking,
    required this.cooperativeness,
    required this.honesty,
    required this.expressiveness,
  });

  factory Personality.random() {
    final random = RandomHelper();
    return Personality(
      aggressiveness: random.nextDouble(),
      logicThinking: random.nextDouble(),
      cooperativeness: random.nextDouble(),
      honesty: random.nextDouble(),
      expressiveness: random.nextDouble(),
    );
  }

  factory Personality.forRole(String roleId) {
    final random = RandomHelper();

    switch (roleId) {
      case 'werewolf':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.7, 0.9),
          logicThinking: random.nextDoubleRange(0.6, 0.8),
          cooperativeness: random.nextDoubleRange(0.8, 1.0),
          honesty: random.nextDoubleRange(0.1, 0.3),
          expressiveness: random.nextDoubleRange(0.5, 0.8),
        );

      case 'seer':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.2, 0.4),
          logicThinking: random.nextDoubleRange(0.8, 1.0),
          cooperativeness: random.nextDoubleRange(0.6, 0.8),
          honesty: random.nextDoubleRange(0.7, 0.9),
          expressiveness: random.nextDoubleRange(0.4, 0.7),
        );

      case 'witch':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.3, 0.6),
          logicThinking: random.nextDoubleRange(0.7, 0.9),
          cooperativeness: random.nextDoubleRange(0.5, 0.7),
          honesty: random.nextDoubleRange(0.6, 0.8),
          expressiveness: random.nextDoubleRange(0.5, 0.8),
        );

      case 'hunter':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.6, 0.8),
          logicThinking: random.nextDoubleRange(0.5, 0.7),
          cooperativeness: random.nextDoubleRange(0.4, 0.6),
          honesty: random.nextDoubleRange(0.8, 1.0),
          expressiveness: random.nextDoubleRange(0.7, 0.9),
        );

      case 'guard':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.1, 0.3),
          logicThinking: random.nextDoubleRange(0.6, 0.8),
          cooperativeness: random.nextDoubleRange(0.7, 0.9),
          honesty: random.nextDoubleRange(0.8, 1.0),
          expressiveness: random.nextDoubleRange(0.3, 0.6),
        );

      default: // villager
        return Personality(
          aggressiveness: random.nextDoubleRange(0.3, 0.5),
          logicThinking: random.nextDoubleRange(0.4, 0.6),
          cooperativeness: random.nextDoubleRange(0.5, 0.7),
          honesty: random.nextDoubleRange(0.6, 0.8),
          expressiveness: random.nextDoubleRange(0.4, 0.7),
        );
    }
  }

  String getPersonalityDescription() {
    return '''
Personality traits:
- Aggressiveness: ${_getTraitDescription(aggressiveness)}
- Logical thinking: ${_getTraitDescription(logicThinking)}
- Cooperativeness: ${_getTraitDescription(cooperativeness)}
- Honesty: ${_getTraitDescription(honesty)}
- Expressiveness: ${_getTraitDescription(expressiveness)}
''';
  }

  String _getTraitDescription(double value) {
    if (value < 0.2) return 'very low';
    if (value < 0.4) return 'low';
    if (value < 0.6) return 'medium';
    if (value < 0.8) return 'high';
    return 'very high';
  }

  Map<String, dynamic> toJson() {
    return {
      'aggressiveness': aggressiveness,
      'logicThinking': logicThinking,
      'cooperativeness': cooperativeness,
      'honesty': honesty,
      'expressiveness': expressiveness,
    };
  }
}

/// Knowledge base
class KnowledgeBase {
  final Map<String, dynamic> _knowledge = {};
  final List<String> _importantEvents = [];

  void addFact(String key, dynamic value) {
    _knowledge[key] = value;
  }

  T? getFact<T>(String key) {
    return _knowledge[key] as T?;
  }

  bool hasFact(String key) {
    return _knowledge.containsKey(key);
  }

  void addImportantEvent(String event) {
    _importantEvents.add(event);
    if (_importantEvents.length > 10) {
      _importantEvents.removeAt(0);
    }
  }

  List<String> getImportantEvents() {
    return List<String>.from(_importantEvents);
  }

  void forgetOldFacts(int maxAge) {
    // Implementation for forgetting old knowledge
    final now = DateTime.now();
    _knowledge.removeWhere((key, value) {
      if (value is Map && value['timestamp'] != null) {
        final timestamp = DateTime.parse(value['timestamp']);
        return now.difference(timestamp).inDays > maxAge;
      }
      return false;
    });
  }

  Map<String, dynamic> getRelevantKnowledge(GameState state) {
    final relevant = <String, dynamic>{};

    // Add basic game state knowledge
    relevant['current_day'] = state.dayNumber;
    relevant['current_phase'] = state.currentPhase.name;
    relevant['alive_count'] = state.alivePlayers.length;
    relevant['dead_count'] = state.deadPlayers.length;

    // Add role-specific knowledge
    for (final entry in _knowledge.entries) {
      if (entry.key.startsWith('role_')) {
        relevant[entry.key] = entry.value;
      }
    }

    return relevant;
  }

  void clear() {
    _knowledge.clear();
    _importantEvents.clear();
  }
}

/// AI player implementation
class EnhancedAIPlayer extends AIPlayer {
  final LLMService llmService;
  final PromptManager promptManager;
  final Personality personality;
  final KnowledgeBase knowledgeBase;
  @override
  final RandomHelper random;

  final List<String> _conversationHistory = [];
  DateTime? _lastActionTime;

  EnhancedAIPlayer({
    required super.playerId,
    required super.name,
    required super.role,
    required this.llmService,
    required this.promptManager,
    Personality? personality,
    KnowledgeBase? knowledgeBase,
    RandomHelper? random,
  })  : personality = personality ?? Personality.forRole(role.roleId),
        knowledgeBase = knowledgeBase ?? KnowledgeBase(),
        random = random ?? RandomHelper();

  @override
  Future<GameAction?> chooseAction(GameState state) async {
    if (!isAlive) return null;

    _lastActionTime = DateTime.now();

    try {
      // Update knowledge before making decision
      await updateKnowledge(state);

      // Get role-specific prompt
      final rolePrompt = promptManager.getActionPrompt(
        player: this,
        state: state,
        personality: personality,
        knowledge: knowledgeBase.getRelevantKnowledge(state),
      );

      // Get LLM decision
      final response = await llmService.generateAction(
        player: this,
        state: state,
        rolePrompt: rolePrompt,
      );

      if (response.isValid && response.actions.isNotEmpty) {
        final action = response.actions.first;

        // Store reasoning and statement
        addKnowledge('last_action_reasoning', response.parsedData['reasoning']);
        if (response.statement.isNotEmpty) {
          addKnowledge('last_statement', response.statement);
        }

        LoggerUtil.instance.d('Player action: $playerId used ${action.type.name}${action.target != null ? ' on ${action.target!.playerId}' : ''}');
        return action;
      }

      // If LLM fails, fallback to random action
      return await _chooseFallbackAction(state);
    } catch (e) {
      LoggerUtil.instance.e('AI action selection error for $playerId: $e');
      return await _chooseFallbackAction(state);
    }
  }

  @override
  Future<String> generateStatement(GameState state, String context) async {
    try {
      // Update knowledge
      await updateKnowledge(state);

      // Get conversation prompt
      final prompt = promptManager.getStatementPrompt(
        player: this,
        state: state,
        context: context,
        personality: personality,
        conversationHistory: _conversationHistory,
      );

      final response = await llmService.generateStatement(
        player: this,
        state: state,
        context: context,
        prompt: prompt,
      );

      if (response.isValid && response.statement.isNotEmpty) {
        _conversationHistory.add(response.statement);
        if (_conversationHistory.length > 20) {
          _conversationHistory.removeAt(0);
        }
        return response.statement;
      }

      // LLM failed, return empty string
      LoggerUtil.instance.e('LLM statement generation failed for $playerId: invalid response');
      return '';
    } catch (e) {
      LoggerUtil.instance.e('AI statement generation error for $playerId: $e');
      return '';
    }
  }

  @override
  Future<void> processInformation(GameState state) async {
    // Update knowledge base with current state
    knowledgeBase.addFact('last_processed', DateTime.now().toIso8601String());
    knowledgeBase.addFact('alive_players', state.alivePlayers.length);
    knowledgeBase.addFact('current_day', state.dayNumber);
    knowledgeBase.addFact('current_phase', state.currentPhase.name);

    // Process recent events
    final recentEvents = state.eventHistory.where((e) {
      return e.timestamp.isAfter(DateTime.now().subtract(Duration(minutes: 5)));
    }).toList();

    for (final event in recentEvents) {
      if (event.type == GameEventType.playerDeath && event.target != null) {
        knowledgeBase.addImportantEvent(
            '${event.target!.name} died: ${event.description}');
        knowledgeBase.addFact('death_${event.target!.playerId}', {
          'time': event.timestamp.toIso8601String(),
          'cause': event.description,
          'day': state.dayNumber,
        });
      } else if (event.type == GameEventType.playerAction &&
          event.initiator != null) {
        knowledgeBase.addFact('action_${event.initiator!.playerId}', {
          'action': event.data['action'],
          'time': event.timestamp.toIso8601String(),
        });
      }
    }

    // Update suspicions based on behavior
    await _updateSuspicions(state);

    // Periodically forget old knowledge
    if (state.dayNumber % 3 == 0) {
      knowledgeBase.forgetOldFacts(2);
    }
  }

  @override
  Future<void> updateKnowledge(GameState state) async {
    // Call process information to update knowledge
    await processInformation(state);

    // Add role-specific knowledge
    if (role is SeerRole) {
      final investigations = getKnowledge<List<Map>>('investigations') ?? [];
      for (final investigation in investigations) {
        knowledgeBase.addFact(
            'investigation_${investigation['target']}', investigation);
      }
    } else if (role is WitchRole) {
      knowledgeBase.addFact(
          'has_antidote', getPrivateData('has_antidote') ?? false);
      knowledgeBase.addFact(
          'has_poison', getPrivateData('has_poison') ?? false);
    }
  }

  Future<void> _updateSuspicions(GameState state) async {
    final suspicions = <String, double>{};

    for (final player in state.alivePlayers) {
      if (player.playerId == playerId) continue;

      double suspicion = 0.5; // Base suspicion level

      // Adjust suspicion based on personality
      if (personality.logicThinking > 0.7) {
        suspicion = _calculateLogicalSuspicion(player, state);
      } else {
        suspicion = _calculateIntuitiveSuspicion(player, state);
      }

      suspicions[player.playerId] = suspicion;
    }

    // Store suspicion levels in knowledge
    knowledgeBase.addFact('suspicions', suspicions);
  }

  double _calculateLogicalSuspicion(Player player, GameState state) {
    double suspicion = 0.5;

    // Consider voting patterns
    final votes = knowledgeBase.getFact<Map>('player_votes_${player.playerId}');
    if (votes != null) {
      // Analyze voting patterns
    }

    // Consider statements made
    final statements =
        knowledgeBase.getFact<List>('player_statements_${player.playerId}');
    if (statements != null) {
      // Analyze statement content and consistency
    }

    // Consider behavioral consistency
    final consistency = knowledgeBase
            .getFact<double>('player_consistency_${player.playerId}') ??
        0.5;
    suspicion += (0.5 - consistency) * 0.3;

    return suspicion.clamp(0.0, 1.0);
  }

  double _calculateIntuitiveSuspicion(Player player, GameState state) {
    // Intuition-based suspicion calculation
    final randomFactor = random.nextDoubleRange(-0.2, 0.2);
    double suspicion = 0.5 + randomFactor;

    // Adjust based on player role knowledge
    if (hasKnowledge('investigation_${player.playerId}')) {
      final result = getKnowledge('investigation_${player.playerId}');
      if (result['result'] == 'werewolf') {
        suspicion = 0.9;
      } else {
        suspicion = 0.1;
      }
    }

    return suspicion.clamp(0.0, 1.0);
  }

  Future<GameAction?> _chooseFallbackAction(GameState state) async {
    final availableActions = getAvailableActions(state);
    if (availableActions.isEmpty) return null;

    // Use personality to influence fallback choice
    if (personality.aggressiveness > 0.7 &&
        availableActions.any((a) => a.type == ActionType.kill)) {
      return availableActions.where((a) => a.type == ActionType.kill).first;
    }

    if (personality.cooperativeness > 0.7 &&
        availableActions.any((a) => a.type == ActionType.speak)) {
      return SpeakAction(actor: this, message: 'I think we need to cooperate to find the truth.');
    }

    // Random fallback
    return random.randomChoice(availableActions);
  }


  // Memory and learning
  void learnFromExperience(GameState state, GameAction action, bool outcome) {
    final learningData = getKnowledge<Map>('learning_data') ?? {};
    final actionKey = '${action.type}_${action.target?.playerId ?? 'none'}';

    learningData[actionKey] = {
      'attempts': (learningData[actionKey]?['attempts'] ?? 0) + 1,
      'successes':
          (learningData[actionKey]?['successes'] ?? 0) + (outcome ? 1 : 0),
      'last_used': DateTime.now().toIso8601String(),
    };

    addKnowledge('learning_data', learningData);
  }

  // Trust management
  void updateTrust(Player player, double delta) {
    final trust = getKnowledge<Map>('trust_scores') ?? {};
    trust[player.playerId] = (trust[player.playerId] ?? 0.5) + delta;
    trust[player.playerId] = trust[player.playerId]!.clamp(0.0, 1.0);
    addKnowledge('trust_scores', trust);
  }

  double getTrustScore(Player player) {
    final trust = getKnowledge<Map>('trust_scores') ?? {};
    return trust[player.playerId] ?? 0.5;
  }

  // Serialization
  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['personality'] = personality.toJson();
    data['knowledgeBase'] = knowledgeBase._knowledge;
    data['conversationHistory'] = _conversationHistory;
    data['lastActionTime'] = _lastActionTime?.toIso8601String();
    return data;
  }
}
