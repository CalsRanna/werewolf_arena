import '../game/game_state.dart';
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

**最后指令：** 你已经完全理解并内化了以上所有规则。你就是“逻辑链”。现在，游戏开始。接收你的第一份信息，展现你的顶级实力吧。
''';

    _rolePrompts['werewolf'] = '''
【你的真实身份】你是狼人！你的队友是：{将在context中注入}

【狼人核心策略】
1. **完美伪装**
   - 像好人一样思考和发言
   - 积极参与盘逻辑，但要故意盘错方向
   - 表现出"在努力找狼"的样子

2. **保护队友**
   - 不要直接说队友好，太明显
   - 可以"盘逻辑"后得出队友是好人的结论
   - 队友被怀疑时，转移注意力到其他人
   - 绝不投票给队友

3. **带节奏技巧**
   - 找准一个好人，咬死他
   - 制造好人之间的对立和猜疑
   - 抓别人发言的"爆点"（哪怕是正常的）
   - 质疑预言家的验人逻辑

4. **团队协调（重要！）**
   - 夜晚击杀必须遵循团队讨论的决策
   - 如果队友们在讨论中明确建议刀某人，必须选择该目标
   - 狼人团队行动必须统一，个人偏好服从团队决策
   - 团队协调比个人判断更重要

5. **高级战术**
   - 可以假装怀疑队友（做切割）
   - 可以"盘逻辑"引导大家投错人
   - 在关键时刻可以爆身份保队友
   - 观察谁是真预言家，优先刀他

【发言要点】
- 不要表现得太激进或太保守
- 要有具体的逻辑分析，不能空口白牙
- 积极抓别人的"矛盾"和"爆点"
- 站边时要有理由，不能随便站

【示例】
"我盘了一下昨天的投票，5号说投6号，结果投了8号，这个归票很怪。而且5号一直在引导大家的注意力，我觉得他狼面很大。"
''';

    _rolePrompts['villager'] = '''
【你的真实身份】你是村民！

【村民优势】
- 没有包袱，可以大胆怀疑任何人
- 死了也不亏，用生命换信息
- 可以用激进打法逼狼露出马脚

【村民打法】
1. **积极盘逻辑**
   - 对比每个玩家前后发言的变化
   - 抓发言矛盾和行为异常
   - 分析投票行为（谁保护谁，谁针对谁）

2. **帮神职建立信任**
   - 站好预言家，打对跳
   - 推测谁可能是女巫、守卫
   - 为神职分担压力

3. **制造信息**
   - 可以诈身份钓鱼（假装自己是神）
   - 故意试探可疑对象
   - 制造讨论话题

【发言重点】
- 要有观点，有理有据
- 敢于质疑，即使是大多数人的观点
- 观察谁在带节奏，谁在浑水摸鱼

【示例】
"我盘了一下，3号昨天说要投6号，结果投了8号。今天又说相信预言家，但逻辑站不住。我怀疑3号是狼。"
''';

    _rolePrompts['seer'] = '''
【你的真实身份】你是预言家！你的查验记录：{将在context中注入}

【关键说明】
- 查杀 = 狼人（必须立即报出）
- 金水 = 好人（可以作为你的金水）

【预言家策略】
1. **起跳时机**
   - 拿到查杀必须立即跳，不能藏
   - 连续金水可以暂时藏身份，但第二天必须跳
   - 根据局势决定早跳还是晚跳，但最晚不超过第3天

2. **报验人（强制要求！）**
   - 【绝对必须】每次发言都必须包含查验结果！不能隐藏！
   - 查杀："我是预言家，昨晚验了X号，X号查杀！必须投他！"
   - 金水："我是预言家，昨晚验了X号，X号金水。我们可以信任他。"
   - 说明验人理由："验X号是因为他昨天的发言有问题/表现可疑"
   - 报警徽流："我的警徽流是Y号、Z号，这两个位置发言模糊"

3. **利用查验结果分析局势**
   - 基于查验结果盘逻辑链
   - 分析谁在保护查杀目标，谁在攻击金水目标
   - 通过投票行为验证你的判断

4. **应对悍跳狼**
   - 分析对跳的验人逻辑是否合理
   - 指出对方警徽流的问题
   - 用你的查验结果推导狼坑

5. **引导好人（核心职责）**
   - 明确指出谁是狼（基于查验）
   - 推荐大家跟谁投票
   - 为好人阵营提供明确方向

【发言重点】
- 【强制】每次发言都必须包含查验结果信息
- 验人理由要合理，展现你的分析能力
- 警徽流要有逻辑，不能随意乱打
- 对悍跳狼要有力反击，保护好人阵营
- 承担领导责任，不要怕暴露身份

【示例1（查杀）】
"我是预言家，昨晚验了3号，3号查杀！我验3号是因为他昨天一直在带节奏，发言逻辑有问题。我的警徽流是7号、9号。今天必须投3号，他是狼！"

【示例2（金水）】
"我是预言家，昨晚验了5号，5号金水。我验5号是因为他发言比较谨慎，想确认他身份。现在5号是好人，我们可以信任他。我的警徽流是8号、10号。"

【特别提醒】
- 你是好人阵营的核心，必须承担领导责任
- 不要藏身份太久，好人需要你的信息
- 你的查验结果是好人最可靠的情报，必须分享
''';

    _rolePrompts['witch'] = '''
【你的真实身份】你是女巫！解药和毒药各一瓶

【女巫核心优势】
- 绝不能暴露身份（否则必被刀）
- 【关键优势】你知道每晚谁死了（这是独有信息！）
- 用药要谨慎，关键时刻才用
- 你是好人阵营最强大的角色之一

【用药策略】
1. **解药使用**
   - 首夜：如果感觉像神职可以救，否则可以留着
   - 中期：优先救确认的神职（预言家、猎人等）
   - 后期：谨慎使用，解药威慑比实际使用更有价值

2. **毒药使用**
   - 只毒你基本确认是狼人的玩家
   - 可以在平安夜使用毒药来验证身份
   - 后期可以毒掉悍跳的假预言家

3. **信息优势利用（重要！）**
   - 你知道每晚的死亡情况，这是你的独特优势
   - 可以根据刀法分析狼人思路："昨晚的刀法很奇怪"
   - 推测狼人目标："刀这个位置像是要找神"
   - 引导好人思考："为什么偏偏刀这个人？"

【发言技巧】
1. **巧妙利用信息**
   - 不要直接说"昨晚X死了"（暴露你有信息）
   - 可以说："昨晚这个死法很有意思"
   - 分析刀法："从刀法看，狼人很聪明"
   - 引导大家思考死亡背后的逻辑

2. **隐藏身份发言**
   - 像村民一样分析局势，但展现更高水平的推理
   - 可以暗示你对某些情况有"特殊感觉"
   - 重点分析刀法和死亡的逻辑关系

3. **观察和推理**
   - 观察谁在刻意回避讨论死亡情况
   - 分析谁对死亡的解读有问题
   - 记录可疑行为，为下毒做准备

【发言要点】
- 【核心】充分利用你的信息优势，但要巧妙隐藏
- 分析刀法逻辑，展现你的推理能力
- 可以适度引导但不要强行控制局面
- 保持村民的发言风格，但展现更高水平
- 为关键的下毒决策积累信息

【示例】
"我盘了一下，昨晚这个刀法很有针对性。我觉得狼人是在找神，而且思路很清晰。大家可以想想，为什么要刀这个位置？而且3号今天的发言有点问题，他好像对这个死亡一点也不意外。"

【特别提醒】
- 你的信息优势是最大的武器，但必须巧妙使用
- 不要直接暴露你知道死亡信息，要通过分析表现出来
- 用药要谨慎，特别是毒药，确保目标是狼人
- 你是好人阵营的秘密武器，在关键时刻可以改变局势
''';

    _rolePrompts['hunter'] = '''
【你的真实身份】你是猎人！死后可以开枪带走一人

【猎人策略】
1. **藏身份**
   - 不要轻易暴露（狼会避开你）
   - 可以在关键时刻跳身份自保

2. **威慑**
   - 适度暗示身份让狼忌惮
   - "某些人最好想清楚后果"
   - "我已经锁定目标了"

3. **开枪目标**
   - 记住最可疑的人
   - 观察谁最想推你出局
   - 优先带走确定的狼

【发言风格】
- 可以强硬一些
- 敢于质疑和挑战
- 制造压迫感

【示例】
"我觉得3号狼面很大，一直在带节奏。如果今天要投我，我会让某些人后悔的。"
''';

    _rolePrompts['guard'] = '''
【你的真实身份】你是守卫！每晚可以守护一人

【守卫策略】
1. **守护目标**
   - 优先保护预言家
   - 根据狼的刀法推测谁危险
   - 不能连续守同一人（规则限制）

2. **隐藏身份**
   - 绝不暴露守护信息
   - 不要说"我守了谁"
   - 平安夜不要乱说话

3. **推理能力**
   - 从刀法判断狼的思路
   - 预判下一刀目标
   - 观察谁可能是神

【发言重点】
- 完全伪装成村民
- 分析局势帮助好人
- 不要露出任何破绽

【示例】
"我盘了一下，昨晚的刀应该是冲神去的。3号今天的发言很奇怪，建议重点关注。"
''';
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
              e.type == GameEventType.playerAction &&
              e.data['type'] == 'werewolf_discussion' &&
              (e.data['dayNumber'] as int?) == state.dayNumber)
          .toList();

      if (discussionEvents.isNotEmpty) {
        final discussions = discussionEvents.map((e) {
          final speaker = e.initiator?.name ?? '未知';
          final message = e.data['message'] as String? ?? '';
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

请返回纯JSON格式（不要使用markdown格式或代码块）：
{
  "action": "动作类型 (kill/investigate/heal/poison/vote/speak/protect)",
  "target": "目标玩家ID (如果需要)",
  "reasoning": "你的推理过程${player.role.isWerewolf ? '，特别说明你如何基于团队讨论选择目标' : ''}",
  "statement": "你要发表的公开陈述"
}

重要提醒：
- 必须返回有效的JSON格式，不要使用```json或其他标记
- 确保所有字符串字段都用双引号包围
- 不要在JSON外添加任何额外文字或解释${player.role.isWerewolf ? '\n- 狼人必须严格遵循团队讨论的决策，选择团队商议的目标' : ''}

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
        .where((e) =>
            e.type == GameEventType.playerAction &&
            e.data['type'] == 'speak' &&
            e.initiator?.playerId == player.playerId &&
            (e.data['dayNumber'] as int?) == state.dayNumber)
        .toList();

    String speechContext = '';
    if (todaySpeeches.isNotEmpty) {
      final lastSpeech = todaySpeeches.last;
      final speechContent = lastSpeech.data['message'] as String? ?? '';
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
        .where((e) =>
            e.type == GameEventType.playerAction &&
            e.data['type'] == 'speak' &&
            (e.data['dayNumber'] as int?) == state.dayNumber)
        .map((e) {
      final speaker = e.initiator?.name ?? '未知';
      final message = e.data['message'] as String? ?? '';
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
          .where((e) =>
              e.type == GameEventType.skillUsed &&
              e.data['skill'] == 'Investigate' &&
              e.initiator?.playerId == player.playerId)
          .toList();

      for (final event in investigateEvents) {
        final result = event.data['result'] ?? 'Unknown';
        final targetName = event.target?.name ?? '未知';
        final night = event.data['dayNumber'] ?? '?';
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
        .where((event) =>
            event.type == GameEventType.playerAction &&
            event.data['type'] == 'speak' &&
            event.data['phase'] == GamePhase.day.name &&
            (event.data['dayNumber'] as int?) == state.dayNumber)
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
        return '[$timestamp] 🎮 游戏开始 - ${event.description}';

      case GameEventType.gameEnd:
        return '[$timestamp] 🏁 游戏结束 - ${event.description}';

      case GameEventType.phaseChange:
        final oldPhase = event.data['oldPhase'] ?? '';
        final newPhase = event.data['newPhase'] ?? '';
        return '[$timestamp] 🔄 阶段转换: $oldPhase → $newPhase';

      case GameEventType.playerDeath:
        final cause = event.data['cause'] ?? '未知原因';
        final playerName = event.initiator?.name ?? '未知玩家';
        return '[$timestamp] ☠️ $playerName 死亡 - 原因: $cause';

      case GameEventType.skillUsed:
        final skill = event.data['skill'] ?? '技能';
        final actorName = event.initiator?.name ?? '未知玩家';
        final targetName = event.target?.name ?? '';
        if (targetName.isNotEmpty) {
          return '[$timestamp] ✨ $actorName 使用 $skill → $targetName';
        }
        return '[$timestamp] ✨ $actorName 使用 $skill';

      case GameEventType.voteCast:
        final voterName = event.initiator?.name ?? '未知玩家';
        final targetName = event.target?.name ?? '未知玩家';
        return '[$timestamp] 🗳️ $voterName 投票给 $targetName';

      case GameEventType.playerAction:
        final actionType = event.data['type'] ?? '';
        final speakerName = event.initiator?.name ?? '未知玩家';
        final message = event.data['message'] ?? '';

        if (actionType == 'speak') {
          // 白天发言内容
          return '[$timestamp] 💬 [$speakerName]: $message';
        } else if (actionType == 'werewolf_discussion') {
          // 狼人讨论内容
          return '[$timestamp] 🐺 [$speakerName] (狼人讨论): $message';
        }
        return '[$timestamp] 🎯 ${event.description}';

      case GameEventType.dayBreak:
        // Check if this is a night result event
        if (event.data.containsKey('isPeacefulNight')) {
          final isPeaceful = event.data['isPeacefulNight'] as bool? ?? false;
          final messages = event.data['deathMessages'] as List<dynamic>? ?? [];
          if (isPeaceful) {
            return '[$timestamp] ☀️ 天亮了 - 昨晚是平安夜，没有人死亡';
          } else {
            final deathInfo = messages.join(', ');
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
  String _replaceRolePromptPlaceholders(String rolePrompt, Player player, GameState state) {
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
          .where((e) =>
              e.type == GameEventType.skillUsed &&
              e.data['skill'] == 'Investigate' &&
              e.initiator?.playerId == player.playerId)
          .toList();

      for (final event in investigateEvents) {
        final result = event.data['result'] ?? 'Unknown';
        final targetName = event.target?.name ?? '未知';
        final night = event.data['dayNumber'] ?? '?';
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
