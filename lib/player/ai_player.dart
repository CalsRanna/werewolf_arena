import 'dart:async';
import 'player.dart';
import 'role.dart';
import '../game/game_state.dart';
import '../game/game_action.dart';
import '../llm/llm_service.dart';
import '../llm/prompt_manager.dart';
import '../utils/random_helper.dart';

/// AI性格特征
class Personality {
  final double aggressiveness; // 激进度 0-1
  final double logicThinking; // 逻辑性 0-1
  final double cooperativeness; // 合作性 0-1
  final double honesty; // 诚实度 0-1
  final double expressiveness; // 表现力 0-1

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
性格特征：
- 激进度: ${_getTraitDescription(aggressiveness)}
- 逻辑性: ${_getTraitDescription(logicThinking)}
- 合作性: ${_getTraitDescription(cooperativeness)}
- 诚实度: ${_getTraitDescription(honesty)}
- 表现力: ${_getTraitDescription(expressiveness)}
''';
  }

  String _getTraitDescription(double value) {
    if (value < 0.2) return '很低';
    if (value < 0.4) return '较低';
    if (value < 0.6) return '中等';
    if (value < 0.8) return '较高';
    return '很高';
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

/// 知识库
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
    // 遗忘旧知识的实现
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

    // 添加基本游戏状态知识
    relevant['current_day'] = state.dayNumber;
    relevant['current_phase'] = state.currentPhase.name;
    relevant['alive_count'] = state.alivePlayers.length;
    relevant['dead_count'] = state.deadPlayers.length;

    // 添加角色特定知识
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

/// AI玩家实现
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
    required super.logger,
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
      // 做决定前更新知识
      await updateKnowledge(state);

      // 获取角色特定提示词
      final rolePrompt = promptManager.getActionPrompt(
        player: this,
        state: state,
        personality: personality,
        knowledge: knowledgeBase.getRelevantKnowledge(state),
      );

      // 获取LLM决策
      final response = await llmService.generateAction(
        player: this,
        state: state,
        rolePrompt: rolePrompt,
      );

      if (response.isValid && response.actions.isNotEmpty) {
        final action = response.actions.first;

        // 存储推理和陈述
        addKnowledge('last_action_reasoning', response.parsedData['reasoning']);
        if (response.statement.isNotEmpty) {
          addKnowledge('last_statement', response.statement);
        }

        logger.playerAction(playerId, action.type.name,
            target: action.target?.playerId);
        return action;
      }

      // 如果LLM失败，回退到随机行动
      return await _chooseFallbackAction(state);
    } catch (e) {
      logger.error('AI action selection error for $playerId: $e');
      return await _chooseFallbackAction(state);
    }
  }

  @override
  Future<String> generateStatement(GameState state, String context) async {
    try {
      // 更新知识
      await updateKnowledge(state);

      // 获取对话提示词
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

      // 回退陈述
      return _generateFallbackStatement(context);
    } catch (e) {
      logger.error('AI statement generation error for $playerId: $e');
      return _generateFallbackStatement(context);
    }
  }

  @override
  Future<void> processInformation(GameState state) async {
    // 用当前状态更新知识库
    knowledgeBase.addFact('last_processed', DateTime.now().toIso8601String());
    knowledgeBase.addFact('alive_players', state.alivePlayers.length);
    knowledgeBase.addFact('current_day', state.dayNumber);
    knowledgeBase.addFact('current_phase', state.currentPhase.name);

    // 处理最近的事件
    final recentEvents = state.eventHistory.where((e) {
      return e.timestamp.isAfter(DateTime.now().subtract(Duration(minutes: 5)));
    }).toList();

    for (final event in recentEvents) {
      if (event.type == GameEventType.playerDeath && event.target != null) {
        knowledgeBase.addImportantEvent(
            '${event.target!.name} 死亡: ${event.description}');
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

    // 根据行为更新怀疑度
    await _updateSuspicions(state);

    // 定期遗忘旧知识
    if (state.dayNumber % 3 == 0) {
      knowledgeBase.forgetOldFacts(2);
    }
  }

  @override
  Future<void> updateKnowledge(GameState state) async {
    // 调用处理信息来更新知识
    await processInformation(state);

    // 添加角色特定知识
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

      double suspicion = 0.5; // 基础怀疑度

      // 根据个性调整怀疑度
      if (personality.logicThinking > 0.7) {
        suspicion = _calculateLogicalSuspicion(player, state);
      } else {
        suspicion = _calculateIntuitiveSuspicion(player, state);
      }

      suspicions[player.playerId] = suspicion;
    }

    // 在知识中存储怀疑度
    knowledgeBase.addFact('suspicions', suspicions);
  }

  double _calculateLogicalSuspicion(Player player, GameState state) {
    double suspicion = 0.5;

    // 考虑投票模式
    final votes = knowledgeBase.getFact<Map>('player_votes_${player.playerId}');
    if (votes != null) {
      // 分析投票模式
    }

    // 考虑发表的陈述
    final statements =
        knowledgeBase.getFact<List>('player_statements_${player.playerId}');
    if (statements != null) {
      // 分析陈述内容和一致性
    }

    // 考虑行为一致性
    final consistency = knowledgeBase
            .getFact<double>('player_consistency_${player.playerId}') ??
        0.5;
    suspicion += (0.5 - consistency) * 0.3;

    return suspicion.clamp(0.0, 1.0);
  }

  double _calculateIntuitiveSuspicion(Player player, GameState state) {
    // 基于直觉的怀疑度计算
    final randomFactor = random.nextDoubleRange(-0.2, 0.2);
    double suspicion = 0.5 + randomFactor;

    // 根据玩家角色知识调整
    if (hasKnowledge('investigation_${player.playerId}')) {
      final result = getKnowledge('investigation_${player.playerId}');
      if (result['result'] == '狼人') {
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

    // 使用个性影响回退选择
    if (personality.aggressiveness > 0.7 &&
        availableActions.any((a) => a.type == ActionType.kill)) {
      return availableActions.where((a) => a.type == ActionType.kill).first;
    }

    if (personality.cooperativeness > 0.7 &&
        availableActions.any((a) => a.type == ActionType.speak)) {
      return SpeakAction(actor: this, message: '我认为我们需要合作找出真相。');
    }

    // 随机回退
    return random.randomChoice(availableActions);
  }

  String _generateFallbackStatement(String context) {
    final statements = [
      '我需要仔细思考一下当前的情况。',
      '从目前的形势来看，我觉得事情并不简单。',
      '让我分析一下现有的信息。',
      '这个情况很复杂，我们需要谨慎行事。',
      '我有一些想法，但需要更多信息来确认。',
    ];

    return random.randomChoice(statements);
  }

  // 记忆和学习
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

  // 信任管理
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

  // 序列化
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
