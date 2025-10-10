import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/events/skill_events.dart';
import 'package:werewolf_arena/core/events/phase_events.dart';
import 'package:werewolf_arena/core/events/system_events.dart';
import 'package:werewolf_arena/core/rules/logic_validator.dart';
import 'enhanced_prompts.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/domain/entities/role.dart';
import 'package:werewolf_arena/core/domain/value_objects/ai_personality.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';

/// 提示词管理器
class PromptManager {
  final Map<String, String> _rolePrompts = {};
  final Map<String, String> _systemPrompts = {};

  PromptManager() {
    _initializePrompts();
  }

  void _initializePrompts() {
    _systemPrompts['base'] = '';
    _systemPrompts['base_template'] = '''你是一个真实的狼人杀玩家，不是AI。

说话风格要求：
- 像真人一样自然聊天，不用过于书面的语言
- 可以用语气词：我觉得、感觉、好像是、应该、可能
- 发言要简洁有力，不要长篇大论分析
- 可以有情绪化的表达：服了、无语、惊了
- 不要说"逻辑链条"、"信息增量"这类分析词汇
- 不要用Markdown格式，直接说话

【狼人杀常识红线 - 比任何发言都更可信的基本规则】
⚠️ **以下规则是判断身份的核心依据，违反这些规则的玩家极有可能是狼人：**

1. **聊爆是最大的狼面**：
   - 如果一个自称预言家的玩家说"随便验的"、"凭感觉"、"中间挑的" → 基本确定是假预言家
   - 如果发言前后矛盾，搞错基本游戏信息 → 基本确定是狼人
   - 真预言家绝对不会有这种低级失误

2. **刀口会说话**：
   - 如果自称预言家的玩家死了，对跳的预言家活下来了 → 活着的嫌疑极大
   - 需要极强的逻辑才能推翻这一点，默认情况下活着的对跳者更可能是狼

3. **女巫的毒药是必杀的**：
   - 如果女巫声称毒了某人但那人没死 → 必有蹊跷，需要全场关注和解释
   - 可能情况：女巫撒谎、守卫保护、或者系统特殊情况
   - 这是一个巨大的疑点，必须追问到底

4. **平安夜的逻辑**：
   - 平安夜意味着要么女巫救人，要么狼人未击中或被守卫保护
   - 平安夜后声称被刀但存活的玩家，如果没有合理解释 → 可疑度极高

5. **投票行为暴露身份**：
   - 好人不会投票给确认的预言家（除非被狼人欺骗）
   - 狼人会保护队友，避免投票给狼队友
   - 反常的投票模式往往能暴露真实身份

【决策原则】
- 当出现明显违反常识红线的玩家时，优先针对他们
- 不要被复杂的"逻辑分析"迷惑，常识往往更可靠
- 宁可错杀一个可疑的，也不要放过一个聊爆的

{scenario_rules}

记住：你是在玩游戏，不是在做分析报告。要用真实玩家的直觉和常识来判断！
''';

    _rolePrompts['werewolf'] = EnhancedPrompts.enhancedWerewolfPrompt;

    _rolePrompts['villager'] = EnhancedPrompts.enhancedVillagerPrompt;

    _rolePrompts['seer'] = EnhancedPrompts.enhancedSeerPrompt;

    _rolePrompts['witch'] = EnhancedPrompts.enhancedWitchPrompt;

    _rolePrompts['hunter'] = EnhancedPrompts.enhancedHunterPrompt;

    _rolePrompts['guard'] = EnhancedPrompts.enhancedGuardPrompt;
  }

  String getActionPrompt({
    required Player player,
    required GameState state,
    required Personality personality,
    required Map<String, dynamic> knowledge,
  }) {
    String rolePrompt = _rolePrompts[player.role.roleId] ?? '';
    final basePrompt = _generateBaseSystemPrompt();

    final contextPrompt = _buildContextPrompt(player, state, knowledge);
    final personalityPrompt = _buildPersonalityPrompt(personality);
    final conversationPrompt = _buildConversationPromptFromEvents(
      player,
      state,
    );

    // 处理角色提示词中的占位符
    rolePrompt = _replaceRolePromptPlaceholders(rolePrompt, player, state);

    // 如果是狼人且在夜晚阶段，添加本轮狼人讨论历史
    String werewolfDiscussionContext = '';
    if (player.role.isWerewolf && state.currentPhase == GamePhase.night) {
      final discussionEvents = state.eventHistory
          .where(
            (e) =>
                e is WerewolfDiscussionEvent && e.dayNumber == state.dayNumber,
          )
          .cast<WerewolfDiscussionEvent>()
          .toList();

      if (discussionEvents.isNotEmpty) {
        final discussions = discussionEvents
            .map((e) {
              final speaker = e.initiator?.name ?? '??';
              return '$speaker: ${e.message}';
            })
            .join('\n');

        werewolfDiscussionContext =
            '''

狼人讨论:
$discussions

根据队友建议选择目标。
''';
      }
    }

    return '''
$basePrompt

$rolePrompt

$personalityPrompt

$contextPrompt

$conversationPrompt$werewolfDiscussionContext

返回JSON: {"action":"动作类型","target":"目标玩家","reasoning":"推理过程"}
''';
  }

  /// 专门为投票阶段生成prompt
  String getVotingPrompt({
    required Player player,
    required GameState state,
    required Personality personality,
    required Map<String, dynamic> knowledge,
    List<Player>? pkCandidates, // PK候选人列表（如果是PK投票）
  }) {
    String rolePrompt = _rolePrompts[player.role.roleId] ?? '';
    final contextPrompt = _buildContextPrompt(player, state, knowledge);
    final personalityPrompt = _buildPersonalityPrompt(personality);
    final conversationPrompt = _buildConversationPromptFromEvents(
      player,
      state,
    );

    // 处理角色提示词中的占位符
    rolePrompt = _replaceRolePromptPlaceholders(rolePrompt, player, state);

    String pkReminder = '';
    if (pkCandidates != null && pkCandidates.isNotEmpty) {
      pkReminder = 'PK候选:${pkCandidates.map((p) => p.name).join(',')}';
    }

    // 狼人投票限制
    String werewolfVotingWarning = '';
    if (player.role.roleId == 'werewolf') {
      werewolfVotingWarning = '队友禁投';
    }

    return '''
$contextPrompt
$personalityPrompt

$conversationPrompt

角色:$rolePrompt

${pkReminder.isNotEmpty ? 'PK候选:${pkCandidates!.map((p) => p.name).join(',')}' : ''}${werewolfVotingWarning.isNotEmpty ? '\n队友禁投' : ''}

返回JSON: {"action":"vote","target":"玩家名","reasoning":"理由"}
''';
  }

  String getStatementPrompt({
    required Player player,
    required GameState state,
    required String context,
    required Personality personality,
  }) {
    String rolePrompt = _rolePrompts[player.role.roleId] ?? '';
    final basePrompt = _generateBaseSystemPrompt();

    final contextPrompt = _buildContextPrompt(player, state, {});
    final personalityPrompt = _buildPersonalityPrompt(personality);
    final conversationPrompt = _buildConversationPromptFromEvents(
      player,
      state,
    );

    // 处理角色提示词中的占位符
    rolePrompt = _replaceRolePromptPlaceholders(rolePrompt, player, state);

    return '''
$basePrompt

$rolePrompt

$personalityPrompt

$contextPrompt

$context

$conversationPrompt

根据角色和性格发言。
''';
  }

  String _buildContextPrompt(
    Player player,
    GameState state,
    Map<String, dynamic> knowledge,
  ) {
    // 精简游戏状态信息
    final alive = state.alivePlayers.map((p) => p.name).join(',');
    final dead = state.deadPlayers.map((p) => p.name).join(',');

    // 预言家查验信息
    String investigationInfo = '';
    if (player.role.roleId == 'seer') {
      final investigations = state.eventHistory
          .whereType<SeerInvestigateEvent>()
          .where((e) => e.initiator?.name == player.name)
          .map((e) {
            final result = e.investigationResult == 'Werewolf' ? '狼' : '好人';
            return '第${e.dayNumber}夜:${e.target!.name}=$result';
          })
          .toList();

      if (investigations.isNotEmpty) {
        investigationInfo = '\n查验记录: ${investigations.join('; ')}';
      }
    }

    // 狼队友信息
    String werewolfTeamInfo = '';
    if (player.role.roleId == 'werewolf') {
      final teammates = state.players
          .where((p) => p.role.isWerewolf && p.name != player.name)
          .map((p) => p.name)
          .toList();
      if (teammates.isNotEmpty) {
        werewolfTeamInfo = '\n队友(禁投): ${teammates.join(',')}';
      }
    }

    return '''
D${state.dayNumber}|${state.currentPhase.name}|存活:$alive|死亡:${dead.isEmpty ? '无' : dead}
你:${player.name}(${player.role.name})$investigationInfo$werewolfTeamInfo''';
  }

  String _buildPersonalityPrompt(Personality personality) {
    return '''
性格: 激进${_getTraitLevel(personality.aggressiveness)}|逻辑${_getTraitLevel(personality.logicThinking)}|合作${_getTraitLevel(personality.cooperativeness)}|诚实${_getTraitLevel(personality.honesty)}|表现${_getTraitLevel(personality.expressiveness)}''';
  }

  String _buildConversationPromptFromEvents(Player player, GameState state) {
    // 设置当前游戏状态，用于逻辑矛盾检测
    _currentState = state;

    final visibleEvents = state.eventHistory
        .where((event) => event.isVisibleTo(player))
        .toList();

    if (visibleEvents.isEmpty) {
      return '【游戏事件】游戏刚开始';
    }

    final formatted = visibleEvents.map((e) => _formatEvent(e)).join('\n');

    // 检查最近是否有平安夜事件，并添加女巫救人信息
    String peacefulNightInfo = '';
    final recentNightResults = visibleEvents
        .whereType<NightResultEvent>()
        .toList();

    if (recentNightResults.isNotEmpty) {
      final latestNightResult = recentNightResults.last;
      if (latestNightResult.isPeacefulNight) {
        // 查找当夜的女巫救人事
        final healEvents = state.eventHistory
            .whereType<WitchHealEvent>()
            .where((e) => e.dayNumber == latestNightResult.dayNumber)
            .toList();

        if (healEvents.isNotEmpty) {
          peacefulNightInfo = '昨晚是平安夜';
        }
      }
    }

    return '''
【游戏事件】
$formatted$peacefulNightInfo''';
  }

  /// 格式化单个事件为可读文本，包含逻辑矛盾检测
  String _formatEvent(GameEvent event) {
    // 对于发言事件，使用逻辑矛盾检测器
    if (event is SpeakEvent && _currentState != null) {
      return LogicContradictionDetector.formatEventWithTags(
        event,
        _currentState!,
      );
    }

    // 其他事件使用原有逻辑
    switch (event.type) {
      case GameEventType.gameStart:
        return '游戏开始';

      case GameEventType.gameEnd:
        return '游戏结束';

      case GameEventType.phaseChange:
        if (event is PhaseChangeEvent) {
          return '${event.oldPhase.name}→${event.newPhase.name}';
        } else if (event is JudgeAnnouncementEvent) {
          return '📢 ${event.announcement}';
        }
        return '阶段转换';

      case GameEventType.playerDeath:
        if (event is DeadEvent) {
          return '${event.victim.name}死亡(${event.cause.name})';
        }
        return '玩家死亡';

      case GameEventType.skillUsed:
        final actor = event.initiator?.name ?? '??';
        if (event is WerewolfKillEvent) {
          return '$actor刀${event.target!.name}';
        } else if (event is GuardProtectEvent) {
          return '$actor守${event.target!.name}';
        } else if (event is SeerInvestigateEvent) {
          return '$actor验${event.target!.name}:${event.investigationResult}';
        } else if (event is WitchHealEvent) {
          return '$actor救${event.target!.name}(重要：该玩家存活)';
        } else if (event is WitchPoisonEvent) {
          return '$actor毒${event.target!.name}';
        } else if (event is HunterShootEvent) {
          return '$actor枪${event.target!.name}';
        }
        return '$actor使用技能';

      case GameEventType.voteCast:
        final voter = event.initiator?.name ?? '??';
        final target = event.target?.name ?? '??';
        return '$voter投$target';

      case GameEventType.playerAction:
        if (event is SpeakEvent) {
          final speaker = event.speaker.name;
          if (event.speechType == SpeechType.normal) {
            return '$speaker: ${event.message}';
          } else if (event.speechType == SpeechType.lastWords) {
            return '$speaker(遗言): ${event.message}';
          } else if (event.speechType == SpeechType.werewolfDiscussion) {
            return '$speaker(狼): ${event.message}';
          }
        } else if (event is SpeechOrderAnnouncementEvent) {
          final order = event.speakingOrder.map((p) => p.name).join('→');
          return '📣 发言顺序: $order (${event.direction})';
        }
        // 直接返回事件类型，让 LLM 理解结构化数据
        return '事件类型: ${event.type.name}';

      case GameEventType.dayBreak:
        if (event is NightResultEvent) {
          if (event.isPeacefulNight) {
            return '🌙 平安夜！无人死亡';
          } else {
            final deaths = event.deathEvents
                .map((e) => e.victim.name)
                .join(',');
            return '天亮:$deaths死亡';
          }
        }
        return '天亮';

      case GameEventType.nightFall:
        return '天黑';
    }
  }

  // 存储当前游戏状态的引用，用于逻辑检测
  GameState? _currentState;

  String _getTraitLevel(double value) {
    if (value < 0.2) return '很低';
    if (value < 0.4) return '较低';
    if (value < 0.6) return '中';
    if (value < 0.8) return '高';
    return '很高';
  }

  // Customization methods
  void setRolePrompt(String roleId, String prompt) {
    _rolePrompts[roleId] = prompt;
  }

  void setSystemPrompt(String key, String prompt) {
    _systemPrompts[key] = prompt;
  }

  void loadCustomPrompts(
    Map<String, String> rolePrompts,
    Map<String, String> systemPrompts,
  ) {
    rolePrompts.forEach((key, value) {
      _rolePrompts[key] = value;
    });
    systemPrompts.forEach((key, value) {
      _systemPrompts[key] = value;
    });
  }

  /// 生成当前场景的基础系统提示词
  String _generateBaseSystemPrompt() {
    final gameParameters = FlutterGameParameters.instance;
    final currentScenario = gameParameters.scenario;

    if (currentScenario == null) {
      // 如果没有设置场景，使用默认基础提示词
      return '你是狼人杀游戏的高手玩家。';
    }

    final template = _systemPrompts['base_template'] ?? '';
    final scenarioRules = currentScenario.rulesDescription;

    return template.replaceAll('{scenario_rules}', scenarioRules);
  }

  /// 替换角色提示词中的占位符
  String _replaceRolePromptPlaceholders(
    String rolePrompt,
    Player player,
    GameState state,
  ) {
    String replacedPrompt = rolePrompt;

    if (player.role.roleId == 'werewolf') {
      // 替换狼人队友信息
      final teammates = state.players
          .where((p) => p.role.isWerewolf && p.name != player.name)
          .map((p) => p.name)
          .toList();

      if (teammates.isNotEmpty) {
        replacedPrompt = replacedPrompt.replaceAll(
          '{teammates}',
          teammates.join(', '),
        );
      } else {
        replacedPrompt = replacedPrompt.replaceAll('{teammates}', '暂无队友');
      }
    } else if (player.role.roleId == 'seer') {
      // 替换预言家查验记录
      final investigations = <String>[];
      final investigateEvents = state.eventHistory
          .whereType<SeerInvestigateEvent>()
          .where((e) => e.initiator?.name == player.name)
          .toList();

      for (final event in investigateEvents) {
        final result = event.investigationResult;
        final targetName = event.target!.name;
        final night = event.dayNumber ?? '?';
        final resultDesc = result == 'Werewolf' ? '狼人(查杀)' : '好人(金水)';
        investigations.add('第$night夜查验$targetName: $resultDesc');
      }

      if (investigations.isNotEmpty) {
        replacedPrompt = replacedPrompt.replaceAll(
          '{investigations}',
          investigations.join('；'),
        );
      } else {
        replacedPrompt = replacedPrompt.replaceAll(
          '{investigations}',
          '暂无查验记录',
        );
      }
    } else if (player.role.roleId == 'guard') {
      // 替换守卫可守护目标列表
      final guardRole = player.role as GuardRole;
      final availableTargets = guardRole.getAvailableTargets(state);
      final lastGuarded = guardRole.getLastGuarded(state);

      String targetsInfo = '';
      if (availableTargets.isNotEmpty) {
        targetsInfo =
            '可守护玩家: ${availableTargets.map((p) => p.name).join(', ')}';
      } else {
        targetsInfo = '无可守护玩家';
      }

      String lastGuardedInfo = '';
      if (lastGuarded != null) {
        lastGuardedInfo = '上次守护: ${lastGuarded.name}（今晚不可守护）';
      } else {
        lastGuardedInfo = '上次守护: 无';
      }

      replacedPrompt = replacedPrompt.replaceAll(
        '{available_targets}',
        targetsInfo,
      );

      replacedPrompt = replacedPrompt.replaceAll(
        '{last_guarded}',
        lastGuardedInfo,
      );
    }

    return replacedPrompt;
  }

  // Export prompts for debugging
  Map<String, dynamic> exportAllPrompts() {
    return {
      'systemPrompts': Map.from(_systemPrompts),
      'rolePrompts': Map.from(_rolePrompts),
    };
  }
}
