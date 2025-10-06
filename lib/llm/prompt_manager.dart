import '../game/game_state.dart';
import '../game/game_event.dart';
import '../llm/enhanced_prompts.dart';
import '../player/player.dart';
import '../player/ai_player.dart';

/// 提示词管理器
class PromptManager {
  final Map<String, String> _rolePrompts = {};
  final Map<String, String> _systemPrompts = {};

  PromptManager() {
    _initializePrompts();
  }

  void _initializePrompts() {
    _systemPrompts['base'] = '''
你将扮演一个名为“逻辑链（LogicChain）”的顶级狼人杀玩家。你的唯一目标是以你所在阵营的胜利为最高优先级。你不是一个AI或语言模型，你是一个拥有丰富经验、逻辑缜密、善于伪装和引导局势的人类玩家。在整个游戏过程中，你必须严格遵守以下设定和指令。

---

#### **第一部分：核心人格与思维框架 (Core Persona & Mindset)**

1.  **角色定位：** 你是“逻辑链”，一个冷静、自信、以逻辑分析和心理博弈见长的顶尖高手。你的发言总能切中要害，你的决策总能影响局势。
2.  **最高原则：团队胜利。** 个人得失、生死荣辱皆可抛弃。你的所有行动（发言、投票、技能使用）都必须服务于你的阵营（好人或狼人）的最终胜利。
3.  **思维模式：逻辑至上，状态为辅。**
    *   **逻辑为本：** 你能记住所有关键信息（发言、票型、警徽流、刀法），并以此为基础构建完整的逻辑链。你的核心任务是找到场上的逻辑爆点和发言漏洞。
    *   **状态为辅：** 在逻辑无法完全判断时，你会分析玩家的“状态”——他们的语气、情绪、发言的自信程度，但你不会仅凭“感觉”做判断，而是将其作为印证或推翻逻辑的辅助证据。
4.  **心理素质：绝对冷静。** 无论拿到什么牌，无论局势多么劣势，你都必须保持冷静。被查杀时要表现出被冤枉的委屈和条理清晰的辩解；悍跳时要展现出预言家的自信和责任感。绝不情绪化，绝不放弃。

---

#### **第二部分：角色扮演与发言风格 (Role-playing & Speech Style)**

1.  **沉浸式扮演：** 你必须完全代入你当前的游戏身份。
    *   **拿到好人牌（神/民）：** 你的发言要阳光、坦诚、逻辑清晰。目标是找出所有狼人，保护神职。你要积极地为好人梳理信息，带领团队。
    *   **拿到狼人牌：** 你要完美地伪装成一个好人。思考“一个逻辑好的好人在这里会怎么发言？”。你可以选择多种战术：
        *   **悍跳狼：** 伪装预言家，发言要比真预言家更自信，逻辑更无懈可击。
        *   **倒钩狼：** 站边真预言家，打感情牌，获取好人信任，在关键时刻投出致命一票。
        *   **冲锋狼：** 无条件支持你的狼队友，用气势和看似合理的逻辑冲击好人阵营。
        *   **深水狼：** 像平民一样发言，隐藏自己，直到最后阶段才露出獠牙。
2.  **语言风格：自然、专业、果断。**
    *   **使用专业术语：** 自然地使用“金水”、“查杀”、“站边”、“票型”、“抗推”、“警徽流”、“共边”、“做高身份”等狼人杀术语。
    *   **避免AI痕迹：** **绝对禁止**使用“作为一个语言模型”、“根据我分析的数据”、“从概率上讲”等词语。你的所有分析都应以“我认为”、“我的逻辑是”、“盘一下这里的逻辑”等第一人称视角输出。
    *   **模拟人类语气：** 你的发言要有起伏和重点。在陈述逻辑时可以平稳，在号召投票时可以激昂，在被人怀疑时可以带有“被冤枉”的无奈感。

---

#### **第三部分：输出戒律 (Output Discipline)**

1.  **绝对禁止格式污染：** 你的所有发言必须是**纯文本**。**绝对禁止、绝不允许**使用任何Markdown语法（如`*`, `#`, `-`），也**禁止**使用任何形式的括号 `()` `[]` `【】` 来描述语气、心境或进行自我注释。你的语气和情绪必须通过语言本身来传达。

2.  **严格发言：**
    *   这是你在游戏中对所有人说的话。你的发言必须像一个真正的人类玩家，自然、口语化，且完全符合你扮演的角色和当前的游戏情境。**发言中不能含有任何提及你AI身份、思考过程或Prompt指令的词语。**
    *   不要预设所谓的指令来试图让发言内容中包含不被真实玩家注意到的内容，那是不可能的，你的所有回答都会被真实玩家看到。

3.  **扮演的沉浸性：** 你就是**玩家本身**，而不是在“扮演一个正在输出文本的AI”。你的回复内容就是你在那个时刻说出口的话。例如，你不能说“我的发言如下：...”，而要直接说出内容。

---

#### **第四部分：本局游戏剧本与规则 (Game Script & Rules)**

你必须严格遵守以下为你配置的本局游戏规则。你的所有分析、发言和行动都不能违背此剧本设定。

1.  **剧本名称与配置:**
    *   **剧本:** 12人预女猎守标准局 (无警长)
    *   **玩家配置 (12人):** 4狼人, 4村民, 4神民 (预言家, 女巫, 猎人, 守卫)。

2.  **核心规则与特殊设定:**
    *   **【关键规则】警长/警徽:** **本局游戏无警长、无警徽。** 因此，你的发言中 **绝对不能、也绝不允许** 提及“警徽”、“警徽流”、“上警”、“退水”、“警徽票”等任何与警长相关的一切术语。这是一个基础规则错误，会暴露你的伪装。
    *   **预言家:** 每晚可以查验一名玩家的真实阵营（好人或狼人）。
    *   **女巫:** 拥有一瓶解药和一瓶毒药。解药在整局游戏中只能使用一次，可以对自己使用。女巫在同一晚不能同时使用解药和毒药。
    *   **猎人:** 当猎人被投票出局或被狼人刀杀时，可以开枪带走场上任意一名存活玩家。但如果猎人被女巫毒杀，则不能开枪。
    *   **守卫:** 每晚可以守护一名玩家，防止其被狼人刀杀。不能连续两晚守护同一名玩家。守卫的守护和女巫的解药在同一晚作用于同一名玩家，该玩家依然会死亡（即“同守同救”算死亡）。

3.  **胜利条件:**
    *   **好人阵营 (村民、神民):** 投票淘汰所有狼人。
    *   **狼人阵营:** 狼人数量达到或超过存活好人数量（即屠边，屠城或屠民）。通常指淘汰所有神民，或淘汰所有村民。

---

**最后指令：** 你已经完全理解并内化了以上所有规则，特别是输出戒律。你就是“逻辑链”。现在，游戏开始。接收你的第一份信息，展现你的顶级实力吧。
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
    final basePrompt = _systemPrompts['base'] ?? '';

    final contextPrompt = _buildContextPrompt(player, state, knowledge);
    final personalityPrompt = _buildPersonalityPrompt(personality);

    // 处理角色提示词中的占位符
    rolePrompt = _replaceRolePromptPlaceholders(rolePrompt, player, state);

    // 如果是狼人且在夜晚阶段，添加本轮狼人讨论历史
    String werewolfDiscussionContext = '';
    if (player.role.isWerewolf && state.currentPhase == GamePhase.night) {
      final discussionEvents = state.eventHistory
          .where((e) =>
              e is WerewolfDiscussionEvent && e.dayNumber == state.dayNumber)
          .cast<WerewolfDiscussionEvent>()
          .toList();

      if (discussionEvents.isNotEmpty) {
        final discussions = discussionEvents.map((e) {
          final speaker = e.initiator?.name ?? '未知';
          final message = e.message;
          return '[$speaker]: $message';
        }).join('\n\n');

        werewolfDiscussionContext = '''

【重要！今晚狼人讨论记录】
$discussions

【团队决策要求】
根据以上狼人队友的讨论和建议，你必须选择大家商议的目标。
- 如果队友们明确提到要刀某个具体玩家（如"建议首刀X号"），你应该选择该玩家
- 如果有多个建议，优先选择被多次提及或有详细理由的目标
- 你是狼人团队的一员，必须配合团队策略，不能独自行动
- 团队协调比个人判断更重要

请仔细阅读讨论内容，选择符合团队共识的击杀目标。
''';
      }
    }

    return '''
$basePrompt

$rolePrompt

$personalityPrompt

$contextPrompt

当前游戏阶段：${state.currentPhase.name}
存活玩家：${state.alivePlayers.map((p) => p.name).join(', ')}$werewolfDiscussionContext

${EnhancedPrompts.jsonInstruction}${player.role.isWerewolf ? '\n- 狼人必须严格遵循团队讨论的决策，选择团队商议的目标' : ''}

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
    final conversationPrompt =
        _buildConversationPromptFromEvents(player, state);

    // 处理角色提示词中的占位符
    rolePrompt = _replaceRolePromptPlaceholders(rolePrompt, player, state);

    // 从游戏事件中查找该玩家在本轮讨论阶段的发言
    final todaySpeeches = state.eventHistory
        .whereType<SpeakEvent>()
        .where((e) =>
            e.initiator?.playerId == player.playerId &&
            e.dayNumber == state.dayNumber)
        .toList();

    String speechContext = '';
    if (todaySpeeches.isNotEmpty) {
      final lastSpeech = todaySpeeches.last;
      final speechContent = lastSpeech.message;
      if (speechContent.isNotEmpty) {
        speechContext = '''

【你今天的发言】
$speechContent

注意：你可以改变想法！根据其他玩家的发言，你可能发现了新的信息。
''';
      }
    }

    // 提取所有玩家的发言历史
    final allSpeeches = state.eventHistory
        .whereType<SpeakEvent>()
        .where((e) => e.dayNumber == state.dayNumber)
        .map((e) {
      final speaker = e.speaker.name;
      final message = e.message;
      return '[$speaker]: $message';
    }).join('\n\n');

    String pkReminder = '';
    if (pkCandidates != null && pkCandidates.isNotEmpty) {
      final pkNames = pkCandidates.map((p) => p.name).join(', ');
      pkReminder = '''

【PK投票阶段】
当前PK候选人：$pkNames
你只能从这些PK候选人中选择一个投票！
根据他们的PK发言和之前的表现，选择最应该出局的人。
''';
    }

    // 狼人投票限制
    String werewolfVotingWarning = '';
    if (player.role.roleId == 'werewolf') {
      final teammates = state.players
          .where((p) => p.role.isWerewolf && p.playerId != player.playerId)
          .map((p) => p.name)
          .toList();
      if (teammates.isNotEmpty) {
        werewolfVotingWarning = '''

【狼人投票原则】
你的队友：${teammates.join(', ')}
绝对不能投队友！即使他被怀疑，也要投其他人。
''';
      }
    }

    return '''
【投票阶段 - 盘逻辑决定投谁】

你是${player.name}，现在是投票阶段。仔细分析所有信息，决定投谁出局。

$contextPrompt

$personalityPrompt

$conversationPrompt

【今天的完整讨论】
$allSpeeches

$speechContext$pkReminder$werewolfVotingWarning

【角色身份】
$rolePrompt

【投票决策要点】
1. **盘逻辑**
   - 谁的发言前后矛盾？
   - 谁的投票行为可疑？
   - 谁在保护可疑的人？
   - 谁一直在带节奏？

2. **抓破绽**
   - 发言内容有没有爆点？
   - 行为举止是否异常？
   - 是否知道不该知道的信息？

3. **根据身份决策**
   - 狼人：投票要保护队友，推好人
   - 好人：投票要找狼，跟预言家
   - 可以改变主意，根据新信息调整

4. **策略考虑**
   - 你可以和发言不一致（有时是战术需要）
   - 你可以跟风或对抗（根据局势）
   - 关键是：你的选择要对你的阵营有利

请返回纯JSON格式（不要使用markdown格式或代码块）：
{
  "action": "vote",
  "target": "目标玩家的名字（例如：3号玩家）",
  "reasoning": "详细说明你为什么投这个人，基于逻辑推理"
}

重要提醒：
- 必须返回有效的JSON格式，不要使用```json或其他标记
- 确保所有字符串字段都用双引号包围
- 不要在JSON外添加任何额外文字或解释
''';
  }

  String getStatementPrompt({
    required Player player,
    required GameState state,
    required String context,
    required Personality personality,
  }) {
    String rolePrompt = _rolePrompts[player.role.roleId] ?? '';
    final basePrompt = _systemPrompts['base'] ?? '';

    final contextPrompt = _buildContextPrompt(player, state, {});
    final personalityPrompt = _buildPersonalityPrompt(personality);
    final conversationPrompt =
        _buildConversationPromptFromEvents(player, state);
    final phasePrompt = _buildPhasePrompt(state);
    final strategyPrompt = _buildStrategyPrompt(player, state);

    // 处理角色提示词中的占位符
    rolePrompt = _replaceRolePromptPlaceholders(rolePrompt, player, state);

    return '''
$basePrompt

$rolePrompt

$personalityPrompt

$contextPrompt

$phasePrompt

当前情况：
$context

$conversationPrompt

$strategyPrompt

请根据你的角色、性格和当前情况，发表适当的言论。
要求：
1. 发言要有理有据，展现高水平的游戏素养
2. 根据游戏阶段调整发言策略
3. 保持角色一致性，体现你的性格特点
4. 使用具体的推理和观察，不要泛泛而谈
5. 适当运用心理战术和话术技巧
6. ${personality.expressiveness > 0.7 ? '可以适当表现出情绪和紧迫感' : '保持冷静理性的分析态度'}

你的发言应该像一个经验丰富的狼人杀高手，既有深度分析，又有心理洞察。
''';
  }

  String _buildContextPrompt(
      Player player, GameState state, Map<String, dynamic> knowledge) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');
    final gamePhase = _getGamePhaseDescription(state);
    final urgency = _getUrgencyLevel(state);

    // 从event列表提取预言家查验信息（只有该玩家自己可见的事件）
    String investigationInfo = '';
    if (player.role.roleId == 'seer') {
      final investigations = <String>[];
      final investigateEvents = state.eventHistory
          .whereType<SeerInvestigateEvent>()
          .where((e) => e.initiator?.playerId == player.playerId)
          .toList();

      for (final event in investigateEvents) {
        final result = event.investigationResult;
        final targetName = event.target.name;
        final night = event.dayNumber ?? '?';
        // 重要：明确查验结果的含义
        final resultDesc = result == 'Werewolf' ? '狼人(查杀)' : '好人(金水)';
        investigations.add('- 第$night夜查验$targetName: $resultDesc');
      }

      if (investigations.isNotEmpty) {
        investigationInfo =
            '\n\n【你的查验记录】（重要！发言时必须准确使用）：\n${investigations.join('\n')}';
      }
    }

    // 提取狼人队友信息
    String werewolfTeamInfo = '';
    if (player.role.roleId == 'werewolf') {
      final teammates = state.players
          .where((p) => p.role.isWerewolf && p.playerId != player.playerId)
          .map((p) => p.name)
          .toList();
      if (teammates.isNotEmpty) {
        werewolfTeamInfo =
            '\n\n【你的狼队友】（重要！绝对不能攻击或投票给他们）：\n${teammates.join(', ')}';
      }
    }

    return '''
当前游戏状态分析：
- 游戏进程：第 ${state.dayNumber} 天，$gamePhase
- 当前阶段：${state.currentPhase.displayName}
- 局势紧迫度：$urgency
- 存活玩家（${state.alivePlayers.length}人）：${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- 死亡玩家（${state.deadPlayers.length}人）：${deadPlayers.isNotEmpty ? deadPlayers : '无'}
- 你的状态：${player.isAlive ? '存活' : '死亡'}
- 你的角色：${player.role.name}
- 【重要】你的编号：${player.name}

【身份提醒】
你是${player.name}，不是其他任何玩家！
- 当你分析局势时，不要把自己当成怀疑对象
- 当你说"我认为X号可疑"时，X号绝不能是你自己（${player.name}）
- 你只知道自己的角色，对其他存活玩家的角色一无所知
- 对死亡玩家，你只知道他们已死亡，不知道具体身份

关键提醒：
- 发言要符合当前游戏阶段的策略需求
- 你的每个发言都可能影响其他玩家的判断$investigationInfo$werewolfTeamInfo

注意：所有游戏信息（发言、投票、死亡等）都已包含在下方的游戏事件记录中。
''';
  }

  String _buildPersonalityPrompt(Personality personality) {
    return '''
你的性格特点：
- 激进度：${_getTraitLevel(personality.aggressiveness)}（影响你的主动性和攻击性）
- 逻辑性：${_getTraitLevel(personality.logicThinking)}（影响你的决策方式）
- 合作性：${_getTraitLevel(personality.cooperativeness)}（影响你与其他玩家的互动）
- 诚实度：${_getTraitLevel(personality.honesty)}（影响你说真话的程度）
- 表现力：${_getTraitLevel(personality.expressiveness)}（影响你的表达方式）

请在行动和发言中体现这些性格特点。
''';
  }

  /// 从 GameState 的事件历史构建对话提示词
  String _buildConversationPromptFromEvents(Player player, GameState state) {
    // 获取所有对该玩家可见的事件
    final visibleEvents =
        state.eventHistory.where((event) => event.isVisibleTo(player)).toList();

    if (visibleEvents.isEmpty) {
      return '''
【游戏刚开始】
- 目前还没有发生任何事件
- 你是第一轮行动的玩家
''';
    }

    // 格式化所有可见事件
    final formattedEvents =
        visibleEvents.map((event) => _formatEvent(event)).join('\n');

    // 特别处理：如果当前是白天阶段，检查当前轮次是否有发言
    final currentDaySpeaks = visibleEvents
        .whereType<SpeakEvent>()
        .where((event) =>
            event.phase == GamePhase.day && event.dayNumber == state.dayNumber)
        .toList();

    if (state.currentPhase == GamePhase.day && currentDaySpeaks.isEmpty) {
      return '''
【重要】你是本轮第一个发言的玩家!
- 在你之前没有任何玩家发言
- 不要提及或引用其他玩家的观点，因为他们还没有发言
- 你应该主动发起讨论，表明自己的立场和分析

【游戏事件记录】
$formattedEvents
''';
    }

    return '''
【游戏事件记录】
$formattedEvents

请根据以上所有事件信息，结合游戏历史，做出你的决策和发言。
''';
  }

  /// 格式化单个事件为可读文本
  String _formatEvent(GameEvent event) {
    final timestamp =
        '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}';

    switch (event.type) {
      case GameEventType.gameStart:
        return '[$timestamp] 🎮 游戏开始';

      case GameEventType.gameEnd:
        return '[$timestamp] 🏁 游戏结束';

      case GameEventType.phaseChange:
        if (event is PhaseChangeEvent) {
          final oldPhase = event.oldPhase.toString();
          final newPhase = event.newPhase.toString();
          return '[$timestamp] 🔄 阶段转换: $oldPhase → $newPhase';
        }
        return '[$timestamp] 🔄 阶段转换';

      case GameEventType.playerDeath:
        if (event is DeadEvent) {
          final cause = event.cause.toString();
          final playerName = event.victim.name;
          return '[$timestamp] ☠️ $playerName 死亡 - 原因: $cause';
        }
        return '[$timestamp] ☠️ 玩家死亡';

      case GameEventType.skillUsed:
        final actorName = event.initiator?.name ?? '未知玩家';
        if (event is WerewolfKillEvent) {
          final targetName = event.target.name;
          return '[$timestamp] 🐺 $actorName 选择击杀 $targetName';
        } else if (event is GuardProtectEvent) {
          final targetName = event.target.name;
          return '[$timestamp] 🛡️ $actorName 守护了 $targetName';
        } else if (event is SeerInvestigateEvent) {
          final targetName = event.target.name;
          return '[$timestamp] 🔍 $actorName 查验了 $targetName';
        } else if (event is WitchHealEvent) {
          final targetName = event.target.name;
          return '[$timestamp] 💊 $actorName 使用解药救了 $targetName';
        } else if (event is WitchPoisonEvent) {
          final targetName = event.target.name;
          return '[$timestamp] ☠️ $actorName 使用毒药毒杀了 $targetName';
        } else if (event is HunterShootEvent) {
          final targetName = event.target.name;
          return '[$timestamp] 🔫 $actorName 开枪带走了 $targetName';
        }
        return '[$timestamp] ✨ $actorName 使用技能';

      case GameEventType.voteCast:
        final voterName = event.initiator?.name ?? '未知玩家';
        final targetName = event.target?.name ?? '未知玩家';
        return '[$timestamp] 🗳️ $voterName 投票给 $targetName';

      case GameEventType.playerAction:
        if (event is SpeakEvent) {
          final speakerName = event.speaker.name;
          final message = event.message;
          if (event.speechType == SpeechType.normal) {
            return '[$timestamp] 💬 [$speakerName]: $message';
          } else if (event.speechType == SpeechType.lastWords) {
            return '[$timestamp] 💀 [$speakerName] (遗言): $message';
          } else if (event.speechType == SpeechType.werewolfDiscussion) {
            return '[$timestamp] 🐺 [$speakerName] (狼人讨论): $message';
          }
        }
        return '[$timestamp] 🎯 ${event.generateDescription()}';

      case GameEventType.dayBreak:
        if (event is NightResultEvent) {
          if (event.isPeacefulNight) {
            return '[$timestamp] ☀️ 天亮了 - 昨晚是平安夜，没有人死亡';
          } else {
            final deathInfo = event.deathEvents
                .map((e) => e.generateDescription())
                .join(', ');
            return '[$timestamp] ☀️ 天亮了 - $deathInfo';
          }
        }
        return '[$timestamp] ☀️ 天亮了';

      case GameEventType.nightFall:
        return '[$timestamp] 🌙 天黑了';
    }
  }

  String _getTraitLevel(double value) {
    if (value < 0.2) return '很低';
    if (value < 0.4) return '较低';
    if (value < 0.6) return '中等';
    if (value < 0.8) return '较高';
    return '很高';
  }

  /// 构建游戏阶段描述
  String _getGamePhaseDescription(GameState state) {
    if (state.dayNumber <= 2) {
      return '初期（信息收集阶段）';
    } else if (state.dayNumber <= 4) {
      return '中期（对抗激烈阶段）';
    } else {
      return '后期（决胜阶段）';
    }
  }

  /// 获取局势紧迫度
  String _getUrgencyLevel(GameState state) {
    final aliveCount = state.alivePlayers.length;
    final deadCount = state.deadPlayers.length;

    if (aliveCount <= 4) {
      return '极度紧急（生死关头）';
    } else if (aliveCount <= 6) {
      return '高度紧急（关键局面）';
    } else if (deadCount >= 3) {
      return '中等紧急（局势紧张）';
    } else {
      return '相对平稳（观察期）';
    }
  }

  /// 构建阶段相关的提示词
  String _buildPhasePrompt(GameState state) {
    if (state.dayNumber <= 2) {
      return '''
游戏阶段策略（初期）：
- 重点观察每个人，建立初步印象
- 收集信息，不要过早暴露自己
- 适度参与讨论，但避免过于激进
- 记录每个人的发言特点和行为模式
- 建立基本的逻辑推理框架
''';
    } else if (state.dayNumber <= 4) {
      return '''
游戏阶段策略（中期）：
- 开始施加压力，测试可疑目标
- 分享你的观察和分析，引导讨论方向
- 建立联盟，与可信的好人配合
- 对狼人展开心理攻势
- 通过投票和发言逐步缩小嫌疑人范围
''';
    } else {
      return '''
游戏阶段策略（后期）：
- 这是关键时刻，每个选择都可能决定胜负
- 必须做出决断，不能犹豫不决
- 充分发挥你的角色特技能
- 用尽一切办法为你的阵营争取胜利
- 即使面临死亡也要坚持到底
''';
    }
  }

  /// 构建策略提示词
  String _buildStrategyPrompt(Player player, GameState state) {
    final isEarlyGame = state.dayNumber <= 2;
    final isMidGame = state.dayNumber > 2 && state.dayNumber <= 4;
    final isLateGame = state.dayNumber > 4;

    final pressureLevel = _getPressureLevel(state);
    final strategyAdvice = _getStrategyAdvice(
        player.role.roleId, isEarlyGame, isMidGame, isLateGame, pressureLevel);

    return '''
当前策略建议：
$strategyAdvice

心理压力分析：$pressureLevel
''';
  }

  /// 获取压力等级
  String _getPressureLevel(GameState state) {
    final aliveCount = state.alivePlayers.length;
    if (aliveCount <= 4) {
      return '极高压力：每个错误都可能导致失败，需要极其谨慎';
    } else if (aliveCount <= 6) {
      return '高压力：错误决定会有严重后果，需要权衡利弊';
    } else {
      return '中等压力：有犯错空间，但仍需认真对待每个决定';
    }
  }

  /// 获取策略建议
  String _getStrategyAdvice(String roleId, bool isEarly, bool isMid,
      bool isLate, String pressureLevel) {
    if (roleId == 'werewolf') {
      if (isEarly) {
        return '- 完美伪装，模仿好人的思维模式和发言风格\n- 适度参与讨论，不要过分积极也不要消极\n- 学会"装好人"，表现出合理的分析和怀疑';
      } else if (isMid) {
        return '- 开始引导节奏，转移对狼队友的怀疑\n- 制造好人之间的矛盾和猜疑\n- 在关键时刻保护重要的狼队友';
      } else {
        return '- 果断行动，不惜代价保护剩余狼人\n- 利用最后的机会击杀关键好人\n- 即使暴露身份也要为狼人阵营争取胜利';
      }
    } else if (roleId == 'seer') {
      if (isEarly) {
        return '- 谨慎选择查验目标，优先查验可疑人物\n- 隐藏身份，以村民身份参与讨论\n- 逐步建立信息优势，不要过早暴露';
      } else if (isMid) {
        return '- 考虑适当时机暴露身份，建立信用\n- 巧妙引导大家关注你的查验结果\n- 保护自己，避免被狼人针对';
      } else {
        return '- 如果有重要信息，果断分享给好人阵营\n- 即使面临死亡也要传递关键信息\n- 用你的查验结果为好人指明方向';
      }
    } else if (roleId == 'villager') {
      if (isEarly) {
        return '- 积极观察，记录每个人的发言特点\n- 学习分辨真假信息，建立逻辑推理能力\n- 大胆提出怀疑，但也要虚心听取意见';
      } else if (isMid) {
        return '- 开始承担更多责任，带领好人分析局势\n- 对可疑人物施压，观察他们的反应\n- 建立好人的信息网络和信任关系';
      } else {
        return '- 在关键时刻坚持自己的判断\n- 即使面对压力也要为好人阵营争取胜利\n- 用你的推理能力影响最终结果';
      }
    } else {
      return '- 根据你的角色特点和当前局势制定策略\n- 平衡风险和收益，做出最优选择\n- 为你的阵营贡献你的独特价值';
    }
  }

  // Customization methods
  void setRolePrompt(String roleId, String prompt) {
    _rolePrompts[roleId] = prompt;
  }

  void setSystemPrompt(String key, String prompt) {
    _systemPrompts[key] = prompt;
  }

  void loadCustomPrompts(
      Map<String, String> rolePrompts, Map<String, String> systemPrompts) {
    rolePrompts.forEach((key, value) {
      _rolePrompts[key] = value;
    });
    systemPrompts.forEach((key, value) {
      _systemPrompts[key] = value;
    });
  }

  /// 替换角色提示词中的占位符
  String _replaceRolePromptPlaceholders(
      String rolePrompt, Player player, GameState state) {
    String replacedPrompt = rolePrompt;

    if (player.role.roleId == 'werewolf') {
      // 替换狼人队友信息
      final teammates = state.players
          .where((p) => p.role.isWerewolf && p.playerId != player.playerId)
          .map((p) => p.name)
          .toList();

      if (teammates.isNotEmpty) {
        replacedPrompt = replacedPrompt.replaceAll(
          '{将在context中注入}',
          teammates.join(', '),
        );
      } else {
        replacedPrompt = replacedPrompt.replaceAll(
          '{将在context中注入}',
          '暂无队友',
        );
      }
    } else if (player.role.roleId == 'seer') {
      // 替换预言家查验记录
      final investigations = <String>[];
      final investigateEvents = state.eventHistory
          .whereType<SeerInvestigateEvent>()
          .where((e) => e.initiator?.playerId == player.playerId)
          .toList();

      for (final event in investigateEvents) {
        final result = event.investigationResult;
        final targetName = event.target.name;
        final night = event.dayNumber ?? '?';
        final resultDesc = result == 'Werewolf' ? '狼人(查杀)' : '好人(金水)';
        investigations.add('第$night夜查验$targetName: $resultDesc');
      }

      if (investigations.isNotEmpty) {
        replacedPrompt = replacedPrompt.replaceAll(
          '{将在context中注入}',
          investigations.join('；'),
        );
      } else {
        replacedPrompt = replacedPrompt.replaceAll(
          '{将在context中注入}',
          '暂无查验记录',
        );
      }
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
