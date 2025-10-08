import 'dart:async';
import 'player.dart';
import '../../core/state/game_state.dart';
import '../../core/state/game_event.dart';
import '../../infrastructure/llm/llm_service.dart';
import '../../infrastructure/llm/prompt_manager.dart';
import '../../shared/random_helper.dart';
import '../../infrastructure/logging/logger.dart';
import 'ai_personality_state.dart';

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
          aggressiveness: random.nextDoubleRange(0.4, 0.9), // 更大的变化范围
          logicThinking: random.nextDoubleRange(0.3, 0.8), // 降低最低逻辑要求
          cooperativeness: random.nextDoubleRange(0.6, 1.0),
          honesty: random.nextDoubleRange(0.1, 0.4), // 允许更多样性
          expressiveness: random.nextDoubleRange(0.3, 0.9), // 更大表达范围
        );

      case 'seer':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.1, 0.6), // 可以更激进
          logicThinking: random.nextDoubleRange(0.6, 0.9), // 允许非完美逻辑
          cooperativeness: random.nextDoubleRange(0.5, 0.9),
          honesty: random.nextDoubleRange(0.8, 1.0),
          expressiveness: random.nextDoubleRange(0.2, 0.8), // 可以更沉静或激动
        );

      case 'witch':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.2, 0.8), // 更大范围
          logicThinking: random.nextDoubleRange(0.4, 0.8), // 允许直觉决策
          cooperativeness: random.nextDoubleRange(0.4, 0.8),
          honesty: random.nextDoubleRange(0.5, 0.9),
          expressiveness: random.nextDoubleRange(0.3, 0.9),
        );

      case 'hunter':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.4, 0.9), // 更大变化
          logicThinking: random.nextDoubleRange(0.3, 0.7), // 降低逻辑要求
          cooperativeness: random.nextDoubleRange(0.3, 0.7),
          honesty: random.nextDoubleRange(0.7, 1.0),
          expressiveness: random.nextDoubleRange(0.5, 1.0), // 可以非常情绪化
        );

      case 'guard':
        return Personality(
          aggressiveness: random.nextDoubleRange(0.1, 0.5), // 可以有攻击性
          logicThinking: random.nextDoubleRange(0.4, 0.8), // 允许直觉守护
          cooperativeness: random.nextDoubleRange(0.6, 1.0),
          honesty: random.nextDoubleRange(0.7, 1.0),
          expressiveness: random.nextDoubleRange(0.2, 0.7),
        );

      default: // villager
        return Personality(
          aggressiveness: random.nextDoubleRange(0.2, 0.8), // 更大范围
          logicThinking: random.nextDoubleRange(0.2, 0.7), // 允许直觉判断
          cooperativeness: random.nextDoubleRange(0.4, 0.8),
          honesty: random.nextDoubleRange(0.5, 0.9),
          expressiveness: random.nextDoubleRange(0.3, 0.9), // 可以很情绪化
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
  final OpenAIService llmService;
  final PromptManager promptManager;
  final Personality personality;
  late final AIPersonalityState personalityState; // 性格状态系统

  DateTime? _lastActionTime;

  EnhancedAIPlayer({
    required super.name,
    required super.role,
    required this.llmService,
    required this.promptManager,
    super.modelConfig,
    Personality? personality,
    RandomHelper? random,
  })  : personality = personality ?? Personality.forRole(role.roleId),
        super(random: random ?? RandomHelper()) {
    // 初始化性格状态
    _initializePersonalityState();
  }

  /// 初始化性格状态系统
  void _initializePersonalityState() {
    // 根据角色选择合适的性格类型
    switch (role.roleId) {
      case 'werewolf':
        personalityState = AIPersonalityFactory.createAggressive();
        break;
      case 'seer':
        personalityState = AIPersonalityFactory.createLogical();
        break;
      case 'villager':
        personalityState = AIPersonalityFactory.createFollower();
        break;
      case 'witch':
      case 'hunter':
        personalityState = AIPersonalityFactory.createEmotional();
        break;
      default:
        personalityState = AIPersonalityFactory.createRandom();
    }

    // 用原始性格数值调整基础性格
    personalityState.aggressiveness = personality.aggressiveness;
    personalityState.logicThinking = personality.logicThinking;
    personalityState.cooperativeness = personality.cooperativeness;
    personalityState.honesty = personality.honesty;
    personalityState.expressiveness = personality.expressiveness;
  }

  /// Choose target for night action based on role
  @override
  Future<Player?> chooseNightTarget(GameState state) async {
    if (!isAlive) return null;

    _lastActionTime = DateTime.now();

    try {
      // 初始化信任度（如果还没有）
      if (personalityState.trustLevels.isEmpty) {
        personalityState.initializeTrustLevels(state.players, name);
      }

      // Update knowledge before making decision
      await updateKnowledge(state);

      // 更新个人信念
      personalityState.updatePersonalBeliefs(state);

      // Get role-specific prompt with personality state
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
            .d('Player action: $name chose target ${target.name}', LogCategory.aiDecision);
        return target;
      }

      // If LLM fails, fallback to random target
      return _chooseFallbackTarget(state);
    } catch (e) {
      LoggerUtil.instance.e('AI target selection error for $name: $e');
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
                '$name tried to vote for ${target.name} who is not in PK candidates, choosing fallback');
            return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
          }
        }

        // Store reasoning in action events, not private data
        LoggerUtil.instance.d('$formattedName投票给${target.formattedName}', LogCategory.aiDecision);
        return target;
      }

      // If LLM fails, fallback to random target
      return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
    } catch (e) {
      LoggerUtil.instance.e('AI vote selection error for $name: $e');
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
          pkCandidates.where((p) => p.name != name).toList();
    } else {
      // 普通投票 - 从所有存活玩家中选择
      availableTargets =
          state.alivePlayers.where((p) => p.name != name).toList();
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
        state.alivePlayers.where((p) => p.name != name).toList();

    if (availableTargets.isEmpty) return null;
    return random.randomChoice(availableTargets);
  }

  @override
  Future<String> generateStatement(GameState state, String context) async {
    try {
      // Update knowledge
      await updateKnowledge(state);

      // 分析其他玩家的发言（如果存在）
      _analyzePlayerSpeeches(state);

      // Get conversation prompt with personality state
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
        // 记录发言历史
        personalityState.speechHistory.add(response.statement);
        if (personalityState.speechHistory.length > 5) {
          personalityState.speechHistory.removeAt(0); // 只保留最近5次发言
        }

        return response.statement;
      }

      // LLM failed, return empty string
      LoggerUtil.instance.e(
          'LLM statement generation failed for $name: invalid response - ${response.errors.join(', ')}');
      return '';
    } catch (e) {
      LoggerUtil.instance.e('AI statement generation error for $name: $e');
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

  /// 分析其他玩家的发言并更新信任度
  void _analyzePlayerSpeeches(GameState state) {
    final recentEvents = state.eventHistory.whereType<SpeakEvent>().toList();

    // 只分析最近的5个发言事件
    final recentSpeeches = recentEvents.length > 5
        ? recentEvents.sublist(recentEvents.length - 5)
        : recentEvents;

    for (final speech in recentSpeeches) {
      if (speech.speaker.name != name) {
        final isLogical = _isLogicalSpeech(speech.message);
        personalityState.analyzeSpeech(speech.speaker.name, speech.message, isLogical);
      }
    }
  }

  /// 简单的逻辑性判断
  bool _isLogicalSpeech(String speech) {
    final lowerSpeech = speech.toLowerCase();

    // 检测明显的聊爆发言
    if (lowerSpeech.contains('随便验') ||
        lowerSpeech.contains('凭感觉') ||
        lowerSpeech.contains('没什么理由')) {
      return false;
    }

    // 检测事实性错误
    if (lowerSpeech.contains('死了') || lowerSpeech.contains('挂了')) {
      // 这里应该和游戏状态比对，简化处理
      return false;
    }

    return true;
  }

  /// 记录投票结果并更新状态
  void recordVoteResult(Player target, bool wasCorrect) {
    personalityState.recordVote(target.name);

    if (wasCorrect) {
      personalityState.recordCorrectDecision();
    } else {
      personalityState.recordMistake();
    }
  }

  /// 获取当前的性格状态描述
  String getPersonalityStateDescription() {
    return personalityState.generatePersonalityDescription();
  }

  /// 获取当前对其他玩家的信任度信息
  String getTrustLevelInfo() {
    final info = <String>[];
    personalityState.trustLevels.forEach((playerName, trustLevel) {
      if (trustLevel < 0.3) {
        info.add('怀疑$playerName');
      } else if (trustLevel > 0.8) {
        info.add('信任$playerName');
      }
    });
    return info.join(', ');
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
