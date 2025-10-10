import 'dart:async';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/services/llm/llm_service.dart';
import 'package:werewolf_arena/services/llm/prompt_manager.dart';
import 'package:werewolf_arena/shared/random_helper.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/core/domain/value_objects/ai_personality.dart';

/// AI player implementation
class EnhancedAIPlayer extends AIPlayer {
  final OpenAIService llmService;
  final PromptManager promptManager;
  final Personality personality;
  late final Personality personalityState; // 性格状态系统

  DateTime? _lastActionTime;

  EnhancedAIPlayer({
    required super.name,
    required super.role,
    required this.llmService,
    required this.promptManager,
    super.modelConfig,
    Personality? personality,
    RandomHelper? random,
  }) : personality = personality ?? Personality.forRole(role.roleId),
       super(random: random ?? RandomHelper()) {
    // 初始化性格状态
    _initializePersonalityState();
  }

  /// 初始化性格状态系统
  void _initializePersonalityState() {
    // 根据角色选择合适的性格类型
    switch (role.roleId) {
      case 'werewolf':
        personalityState = PersonalityFactory.createAggressive();
        break;
      case 'seer':
        personalityState = PersonalityFactory.createLogical();
        break;
      case 'villager':
        personalityState = PersonalityFactory.createFollower();
        break;
      case 'witch':
      case 'hunter':
        personalityState = PersonalityFactory.createEmotional();
        break;
      default:
        personalityState = PersonalityFactory.createRandom();
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
        LoggerUtil.instance.d(
          'Player action: $name chose target ${target.name}',
          LogCategory.aiDecision,
        );
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
  Future<Player?> chooseVoteTarget(
    GameState state, {
    List<Player>? pkCandidates,
  }) async {
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
              '$name tried to vote for ${target.name} who is not in PK candidates, choosing fallback',
            );
            return _chooseFallbackVoteTarget(state, pkCandidates: pkCandidates);
          }
        }

        // Store reasoning in action events, not private data
        LoggerUtil.instance.d(
          '$formattedName投票给${target.formattedName}',
          LogCategory.aiDecision,
        );
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
  Player? _chooseFallbackVoteTarget(
    GameState state, {
    List<Player>? pkCandidates,
  }) {
    List<Player> availableTargets;

    if (pkCandidates != null && pkCandidates.isNotEmpty) {
      // PK投票 - 只能从PK候选人中选择
      availableTargets = pkCandidates.where((p) => p.name != name).toList();
    } else {
      // 普通投票 - 从所有存活玩家中选择
      availableTargets = state.alivePlayers
          .where((p) => p.name != name)
          .toList();
    }

    // 如果是狼人，排除队友
    if (role.isWerewolf) {
      availableTargets = availableTargets
          .where((p) => !p.role.isWerewolf)
          .toList();
    }

    if (availableTargets.isEmpty) return null;
    return random.randomChoice(availableTargets);
  }

  /// Fallback target selection
  Player? _chooseFallbackTarget(GameState state) {
    final availableTargets = state.alivePlayers
        .where((p) => p.name != name)
        .toList();

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
        'LLM statement generation failed for $name: invalid response - ${response.errors.join(', ')}',
      );
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
        personalityState.analyzeSpeech(
          speech.speaker.name,
          speech.message,
          isLogical,
        );
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
