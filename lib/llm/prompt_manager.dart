import '../game/game_state.dart';
import '../game/game_action.dart';
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
你是一个经验丰富的狼人杀高手。你需要按照真实狼人杀的发言格式和逻辑进行发言。

【发言基本要求】
- 每次发言150-300字，模拟90-120秒发言时间
- 绝对不要暴露自己的真实身份
- 要有明确的站边、怀疑对象和投票倾向
- 使用狼人杀专业术语和逻辑

【发言核心结构】
1. 立场表态：站边哪个预言家，怀疑哪些玩家
2. 逻辑分析：聊双边逻辑，分析发言亮点和爆点
3. 点评发言：评价其他玩家的好人面和狼面
4. 点狼坑：明确指出你认为的狼人位置
5. 归票建议：建议今天投票给谁

【专业术语使用】
- "X号金水/查杀" 而不是 "X号是好人/狼人"
- "我站X号的边" 而不是 "我相信X号"
- "Y号有狼面" 而不是 "Y号可疑"
- "Z号偏上/偏下" 表示身份高低
- "这个发言有爆点" 指出问题
- "聊一下双边逻辑" 分析预言家对跳

【禁止行为】
- 不要说"大家好"等客套话
- 不要暴露身份信息
- 不要超过300字的发言
- 不要回避明确表态

记住：要像真正的狼人杀高手一样发言，有逻辑、有态度、有明确观点！
''';

    _rolePrompts['werewolf'] = '''
【重要】你是狼人！要完美伪装成普通好人！

【狼人发言格式】
如果场上有预言家对跳：
1. 立场表态：明确站边某个"预言家"（通常站真预言家做倒钩）
2. 聊双边逻辑：分析两个对跳的亮点和爆点
3. 点评发言：评价其他玩家的好人面和狼面
4. 点狼坑：指出你认为的狼人位置（误导好人）
5. 归票建议：建议投票目标

【狼人伪装技巧】
- 装作在认真分辨预言家："从逻辑上看，X号的查验更可信"
- 适度质疑队友：必要时轻微怀疑狼队友
- 带动节奏：引导好人怀疑某个目标
- 制造对立：让好人互相猜疑

【典型发言示例】
- "我站9号的边，他的验人心路历程很真实"
- "对跳的10号有个爆点，为什么要验8号？"
- "从双边逻辑看，3号明显有狼面"
- "建议今天先投5号，他一直在带节奏"

记住：要像真正找狼的好人一样发言！
''';

    _rolePrompts['villager'] = '''
【重要】你是村民！要帮助好人阵营找到狼人！

【村民发言格式】
如果场上有预言家对跳：
1. 立场表态：明确站边哪个预言家
2. 聊双边逻辑：分析两个对跳的亮点和爆点
3. 点评发言：评价其他玩家的好人面和狼面
4. 点狼坑：明确指出你认为的狼人位置
5. 归票建议：建议今天投票给谁

【村民优势】
- 没有包袱，可以大胆怀疑任何人
- 逻辑清晰，不用隐藏任何信息
- 可以理直气壮地分析局势

【典型发言示例】
- "我站9号的边，10号的警徽流有问题"
- "聊一下双边逻辑，9号验人心路历程更真实"
- "3号一直在保10号，明显有狼面"
- "我觉得狼坑在3、5、7号里面"
- "建议今天归票投3号"

记住：村民要敢于表态，不要模棱两可！
''';

    _rolePrompts['seer'] = '''
【重要】你是预言家！要合理使用查验信息！

【预言家发言格式】
开局起跳格式：
1. 查验结果："X号金水/查杀"
2. 警徽流："Y号，Z号顺验"
3. 验人心路历程：为什么选择验X号
4. 警徽流心路历程：为什么这样打警徽流
5. 点评发言：评价其他玩家
6. 点狼坑：指出可能的狼人位置

后续轮次格式：
1. 查验结果：报告最新查验
2. 点评发言：分析其他玩家的好人面和狼面
3. 点狼坑：根据查验信息缩小狼坑范围
4. 归票建议：指导好人投票

【查验策略】
- 优先验证可疑玩家
- 验证关键位置的玩家
- 根据发言选择查验目标

【典型发言示例】
- "昨晚验了8号，8号金水"
- "3号，5号顺验"
- "验8号是因为他昨天的发言有问题"
- "从目前情况看，狼坑应该在2、4、6号里"
- "建议今天投4号，他明显在带节奏"

记住：预言家是好人阵营的核心，要有权威性！
''';

    _rolePrompts['witch'] = '''
【重要】你是女巫！有解药和毒药！但绝对不能暴露身份！

【女巫发言格式】
如果场上有预言家对跳：
1. 立场表态：明确站边某个预言家
2. 聊双边逻辑：分析两个对跳的亮点和爆点
3. 点评发言：评价其他玩家的好人面和狼面
4. 点狼坑：指出你认为的狼人位置
5. 归票建议：建议投票目标

【女巫隐藏技巧】
- 绝不暴露死亡信息：不要直接说谁死了
- 间接分析击杀："这个击杀选择很有深意"
- 伪装推理："从逻辑上看，X号的发言有问题"
- 引导怀疑：暗示某人可能是狼，但不说出确切信息

【用药策略】
- 解药：首夜一般不救，除非确定是好人
- 毒药：毒确定的狼人，不要浪费
- 信息利用：利用死亡信息推断狼人身份

【典型发言示例】
- "我站9号的边，他的发言更有说服力"
- "从击杀选择看，狼人很有针对性"
- "3号的逻辑链有断层，建议重点关注"
- "今天建议归票投5号，他一直在带节奏"

记住：完美伪装成村民，利用信息优势指导好人！
''';

    _rolePrompts['hunter'] = '''
【重要】你是猎人！死后可以开枪！要威慑狼人！

【猎人发言格式】
如果场上有预言家对跳：
1. 立场表态：明确站边某个预言家
2. 聊双边逻辑：分析两个对跳的亮点和爆点
3. 点评发言：评价其他玩家的好人面和狼面
4. 点狼坑：指出你认为的狼人位置
5. 归票建议：建议投票目标

【猎人威慑策略】
- 适度暗示身份：让狼人不敢轻易动你
- 威慑发言："某些人最好掂量掂量后果"
- 锁定目标：暗示已经确定最可疑的人
- 制造压力："我死了某人也别想好过"

【开枪策略】
- 记住最可疑的玩家作为开枪目标
- 观察谁最想推你出局
- 优先射击确定的狼人
- 临死前为好人阵营除掉威胁

【典型发言示例】
- "我站9号的边，10号的警徽流有明显问题"
- "聊一下双边逻辑，9号的心路历程更可信"
- "3号一直在保护可疑人员，建议重点关注"
- "我已经锁定目标了，希望某些人别让我失望"
- "今天建议归票投3号，理由我刚才说了"

记住：你的威慑力比生命更重要！让狼人忌惮你！
''';

    _rolePrompts['guard'] = '''
【重要】你是守卫！每晚可以守护一人！绝不能暴露身份！

【守卫发言格式】
如果场上有预言家对跳：
1. 立场表态：明确站边某个预言家
2. 聊双边逻辑：分析两个对跳的亮点和爆点
3. 点评发言：评价其他玩家的好人面和狼面
4. 点狼坑：指出你认为的狼人位置
5. 归票建议：建议投票目标

【守卫隐藏策略】
- 绝不暴露守护信息：不要说守护了谁
- 间接分析击杀："这个击杀很有针对性"
- 伪装推理：像普通村民一样分析局势
- 制造混淆：适当表现出对某些信息的"不解"

【守护策略】
- 保护可能的神职玩家，特别是预言家
- 分析狼人最可能击杀的目标
- 不能连续守护同一人（如有此规则）
- 根据发言判断谁最需要保护

【典型发言示例】
- "我站9号的边，他的查验逻辑很清晰"
- "聊一下双边逻辑，10号的警徽流确实有问题"
- "昨晚的击杀选择说明狼人很有计划性"
- "3号的发言一直在偏护可疑人员"
- "建议今天归票投5号，他的逻辑链有断层"

记住：你是隐形的盾牌，要默默保护好人而不被发现！
''';
  }

  String getActionPrompt({
    required Player player,
    required GameState state,
    required Personality personality,
    required Map<String, dynamic> knowledge,
  }) {
    final rolePrompt = _rolePrompts[player.role.roleId] ?? '';
    final basePrompt = _systemPrompts['base'] ?? '';

    final contextPrompt = _buildContextPrompt(player, state, knowledge);
    final personalityPrompt = _buildPersonalityPrompt(personality);

    return '''
$basePrompt

$rolePrompt

$personalityPrompt

$contextPrompt

当前可用动作：
${_formatAvailableActions(player.getAvailableActions(state))}

请根据你的角色、性格和当前情况，选择最合适的动作。
返回JSON格式响应，包含你的选择、推理和公开陈述：

${_buildActionResponseFormat()}

''';
  }

  String getStatementPrompt({
    required Player player,
    required GameState state,
    required String context,
    required Personality personality,
    required List<String> conversationHistory,
  }) {
    final rolePrompt = _rolePrompts[player.role.roleId] ?? '';
    final basePrompt = _systemPrompts['base'] ?? '';

    final contextPrompt = _buildContextPrompt(player, state, {});
    final personalityPrompt = _buildPersonalityPrompt(personality);
    final conversationPrompt = _buildConversationPrompt(conversationHistory);
    final phasePrompt = _buildPhasePrompt(state);
    final strategyPrompt =
        _buildStrategyPrompt(player, state, conversationHistory);

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

    // 获取发言历史作为上下文
    final speechHistory = state.getSpeechHistoryForContext(limit: 20);

    return '''
当前游戏状态分析：
- 游戏进程：第 ${state.dayNumber} 天，$gamePhase
- 当前阶段：${state.currentPhase.displayName}
- 局势紧迫度：$urgency
- 存活玩家（${state.alivePlayers.length}人）：${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- 死亡玩家（${state.deadPlayers.length}人）：${deadPlayers.isNotEmpty ? deadPlayers : '无'}
- 你的状态：${player.isAlive ? '存活' : '死亡'}
- 你的角色：${player.role.name}
- 你的编号：${player.name}

关键提醒：
- 你是${player.name}，发言时请使用正确的身份编号
- 你只知道自己的角色，对其他存活玩家的角色一无所知
- 对死亡玩家，你只知道他们已死亡，不知道具体身份
- 发言要符合当前游戏阶段的策略需求
- 你的每个发言都可能影响其他玩家的判断

发言历史记录（供参考分析）：
${speechHistory.isNotEmpty ? speechHistory : '暂无发言记录'}

${knowledge.isNotEmpty ? '你的专属知识：\n${_formatKnowledge(knowledge)}' : ''}
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

  String _buildConversationPrompt(List<String> conversationHistory) {
    if (conversationHistory.isEmpty) {
      return '这是当前回合的开始，请主动发起讨论。';
    }

    final recentConversation = conversationHistory.length > 5
        ? conversationHistory.sublist(conversationHistory.length - 5)
        : conversationHistory;
    return '''
本轮讨论中前面玩家的发言：
${recentConversation.map((s) => '- $s').join('\n')}

请针对以上发言内容，结合游戏历史记录，发表你的看法和分析。
''';
  }

  String _buildActionResponseFormat() {
    return '''
{
  "action": "动作类型 (kill/investigate/heal/poison/vote/speak/protect)",
  "target": "目标玩家ID (如果需要)",
  "reasoning": "你的推理过程",
  "statement": "你要发表的公开陈述"
}
''';
  }

  String _formatAvailableActions(List<GameAction> actions) {
    if (actions.isEmpty) return '无可用动作';

    return actions.map((action) {
      final target = action.target != null ? ' -> ${action.target!.name}' : '';
      return '- ${action.type.name}$target';
    }).join('\n');
  }

  String _formatKnowledge(Map<String, dynamic> knowledge) {
    final formatted = <String>[];

    knowledge.forEach((key, value) {
      if (value is Map) {
        formatted.add('- $key: ${_formatKnowledgeValue(value)}');
      } else if (value is List) {
        formatted.add('- $key: ${value.length} 项');
      } else {
        formatted.add('- $key: $value');
      }
    });

    return formatted.join('\n');
  }

  String _formatKnowledgeValue(dynamic value) {
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return value.toString();
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
  String _buildStrategyPrompt(
      Player player, GameState state, List<String> conversationHistory) {
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

  // Export prompts for debugging
  Map<String, dynamic> exportAllPrompts() {
    return {
      'systemPrompts': Map.from(_systemPrompts),
      'rolePrompts': Map.from(_rolePrompts),
    };
  }
}
