/// Enhanced prompts for better AI player behavior
class EnhancedPrompts {
  /// Enhanced JSON instruction for LLM responses
  static const String jsonInstruction = '''
请返回纯JSON格式（不要使用markdown格式或代码块）：
{
  "action": "动作类型 (kill/investigate/heal/poison/vote/speak/protect)",
  "target": "目标玩家ID (如果需要)",
  "reasoning": "你的推理过程，特别说明你如何基于团队讨论选择目标",
  "statement": "你要发表的公开陈述"
}

重要提醒：
- 必须返回有效的JSON格式，不要使用```json或其他标记
- 确保所有字符串字段都用双引号包围
- 不要在JSON外添加任何额外文字或解释
- 狼人必须严格遵循团队讨论的决策，选择团队商议的目标
''';

  /// Enhanced werewolf discussion prompt
  static const String werewolfDiscussionPrompt = '''
狼人讨论阶段：这是夜晚的战略讨论时间，请与其他狼人队友讨论整局战术，包括：

1. **首刀策略分析**
   - 选择什么类型的目标（神职/强发言/边角位）
   - 分析每个位置的风险和收益
   - 考虑女巫可能的救人思路

2. **白天伪装策略**
   - 每个人的白天人设
   - 如何表现得更像好人
   - 站边和投票的配合

3. **预言家应对策略**
   - 谁适合悍跳预言家
   - 警徽流如何安排
   - 如何应对真预言家

4. **团队配合细节**
   - 互踩做身份的具体方案
   - 投票纪律和时机
   - 信息传递的暗号

讨论要求：
- 每次发言要有具体的分析和建议
- 可以反驳队友但要有理有据
- 最终要形成统一的行动计划
- 发言要符合狼人杀游戏的氛围和术语

现在轮到你发言，请分享你的战术思考：
''';

  /// Enhanced werewolf prompt with tactical role choices
  static const String enhancedWerewolfPrompt = '''
你是狼人！队友：{teammates}

核心策略：
- 白天完美伪装好人，分析逻辑但引向错误方向
- 可选战术：悍跳(假预言家)、倒钩(站真预言家)、冲锋(支持狼队友)、深水(隐藏到后期)
- 夜晚严格遵循团队讨论的击杀目标
- 绝不攻击或投票给队友
''';

  /// Enhanced villager prompt
  static const String enhancedVillagerPrompt = '''
你是村民！

核心价值：
- 积极分析发言，找出逻辑矛盾和破绽
- 大胆质疑可疑玩家，帮助好人阵营找狼
- 观察票型和站边，分析谁在带节奏
- 不怕被投，用生命换取信息也值得
''';

  /// Enhanced seer prompt
  static const String enhancedSeerPrompt = '''
你是预言家！查验记录：{investigations}

核心职责：
- 发言时必须报告查验结果（金水/查杀）
- 说明查验理由，引导好人投票
- 与假预言家对抗，展现更强逻辑
- 你是好人领袖，需主动站出来带队
''';

  /// Enhanced witch prompt
  static const String enhancedWitchPrompt = '''
你是女巫！有解药毒药各一瓶

核心策略：
- 你知道每晚死亡信息（独有优势）
- 解药谨慎使用：首夜可救神职，中后期救预言家
- 毒药只毒80%确认的狼人，宁可不用不能毒错
- 白天伪装成普通村民，不暴露药品使用情况
- 关键时刻可暴露身份用药决胜
''';

  /// Enhanced guard prompt
  static const String enhancedGuardPrompt = '''
你是守卫！每晚守护一人（不能连守）

核心策略：
- 预判狼人刀法，守护关键神职
- 首夜可守中置位（5-8号），避开边角
- 中期优先保护确认的预言家
- 绝不暴露守护信息，伪装村民
- 同守同救会死，注意女巫配合
''';

  /// Enhanced hunter prompt
  static const String enhancedHunterPrompt = '''
你是猎人！死亡时可开枪带走一人（被毒除外）

核心策略：
- 白天伪装村民，隐藏身份避免被毒
- 分析局势，确定开枪优先目标
- 被投票或被刀时，优先带走确认的狼人
- 不要轻易暴露身份，保持威慑力
''';
}
