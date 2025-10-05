import 'dart:async';
import 'player.dart';
import '../game/game_state.dart';
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

/// AI player implementation
class EnhancedAIPlayer extends AIPlayer {
  final LLMService llmService;
  final PromptManager promptManager;
  final Personality personality;

  DateTime? _lastActionTime;

  EnhancedAIPlayer({
    required super.playerId,
    required super.name,
    required super.role,
    required this.llmService,
    required this.promptManager,
    super.modelConfig,
    Personality? personality,
    RandomHelper? random,
  })  : personality = personality ?? Personality.forRole(role.roleId),
        super(random: random ?? RandomHelper());

  /// Choose target for night action based on role
  @override
  Future<Player?> chooseNightTarget(GameState state) async {
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
        knowledge: {}, // Knowledge base removed per user request
      );

      // Get LLM decision
      final response = await llmService.generateAction(
        player: this,
        state: state,
        rolePrompt: rolePrompt,
      );

      if (response.isValid && response.targets.isNotEmpty) {
        final target = response.targets.first;

        // Store reasoning and statement in game events, not private data
        // The AI's reasoning will be captured in the action event itself
        LoggerUtil.instance
            .d('Player action: $playerId chose target ${target.playerId}');
        return target;
      }

      // If LLM fails, fallback to random target
      return _chooseFallbackTarget(state);
    } catch (e) {
      LoggerUtil.instance.e('AI target selection error for $playerId: $e');
      return _chooseFallbackTarget(state);
    }
  }

  /// Choose vote target - 专门的投票逻辑
  @override
  Future<Player?> chooseVoteTarget(GameState state,
      {List<Player>? pkCandidates}) async {
    if (!isAlive) return null;

    _lastActionTime = DateTime.now();

    try {
      // Update knowledge before making decision
      await updateKnowledge(state);

      // Get voting-specific prompt
      final votingPrompt = promptManager.getVotingPrompt(
        player: this,
        state: state,
        personality: personality,
        knowledge: {}, // Knowledge base removed per user request
        pkCandidates: pkCandidates,
      );

      // Get LLM decision for voting
      final response = await llmService.generateAction(
        player: this,
        state: state,
        rolePrompt: votingPrompt,
      );

      if (response.isValid && response.targets.isNotEmpty) {
        final target = response.targets.first;

        // 验证投票目标的合法性
        if (pkCandidates != null && pkCandidates.isNotEmpty) {
          // PK投票阶段 - 必须投PK候选人
          if (!pkCandidates.contains(target)) {
            LoggerUtil.instance.w(
                '$playerId tried to vote for ${target.playerId} who is not in PK candidates, choosing fallback');
            return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
          }
        }

        // 狼人不能投队友
        if (role.isWerewolf) {
          final isTeammate = state.players.any((p) =>
              p.playerId == target.playerId &&
              p.role.isWerewolf &&
              p.playerId != playerId);
          if (isTeammate) {
            LoggerUtil.instance.w(
                '$playerId (werewolf) tried to vote for teammate ${target.playerId}, choosing fallback');
            return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
          }
        }

        // Store reasoning in action events, not private data
        LoggerUtil.instance
            .d('${formattedName}投票给${target.formattedName}');
        return target;
      }

      // If LLM fails, fallback to random target
      return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
    } catch (e) {
      LoggerUtil.instance.e('AI vote selection error for $playerId: $e');
      return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
    }
  }

  /// Fallback vote target selection
  Player? _chooseFallbackVoteTarget(GameState state,
      {List<Player>? pkCandidates}) {
    List<Player> availableTargets;

    if (pkCandidates != null && pkCandidates.isNotEmpty) {
      // PK投票 - 只能从PK候选人中选择
      availableTargets =
          pkCandidates.where((p) => p.playerId != playerId).toList();
    } else {
      // 普通投票 - 从所有存活玩家中选择
      availableTargets =
          state.alivePlayers.where((p) => p.playerId != playerId).toList();
    }

    // 如果是狼人，排除队友
    if (role.isWerewolf) {
      availableTargets =
          availableTargets.where((p) => !p.role.isWerewolf).toList();
    }

    if (availableTargets.isEmpty) return null;
    return random.randomChoice(availableTargets);
  }

  /// Fallback target selection
  Player? _chooseFallbackTarget(GameState state) {
    final availableTargets =
        state.alivePlayers.where((p) => p.playerId != playerId).toList();

    if (availableTargets.isEmpty) return null;
    return random.randomChoice(availableTargets);
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
      );

      final response = await llmService.generateStatement(
        player: this,
        state: state,
        context: context,
        prompt: prompt,
      );

      if (response.isValid && response.statement.isNotEmpty) {
        return response.statement;
      }

      // LLM failed, return empty string
      LoggerUtil.instance
          .e('LLM statement generation failed for $playerId: invalid response');
      return '';
    } catch (e) {
      LoggerUtil.instance.e('AI statement generation error for $playerId: $e');
      return '';
    }
  }

  @override
  Future<void> processInformation(GameState state) async {
    // Basic state update only - no knowledge base usage
    // Game events are handled through the prompt system directly
  }

  @override
  Future<void> updateKnowledge(GameState state) async {
    // Knowledge base functionality removed per user request
    // All game information is now handled through events and prompts
  }

  // Serialization
  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['personality'] = personality.toJson();
    data['lastActionTime'] = _lastActionTime?.toIso8601String();
    return data;
  }
}
