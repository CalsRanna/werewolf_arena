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
狼人讨论阶段：和队友商量今晚的刀法，简单讨论即可：

1. **今晚刀谁**
   - 分析哪个位置像神职
   - 考虑女巫可能救谁
   - 简单商量就行，不用太复杂

2. **白天配合**
   - 谁跳什么身份（如果需要的话）
   - 投票时大致怎么配合

讨论要求：
- 发言简洁自然，像真实玩家聊天
- 避免过于复杂的战术规划
- 可以有不同意见，商量着来
- 不要设定暗号或太复杂的计划

现在请简单发表你的想法：
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

玩法：
- 认真听发言，谁不对劲就盘谁
- 该质疑就质疑，不要怕得罪人
- 死了就死了，遗言要说出自己的想法
- 多想想谁像狼，保护像神的人
''';

  /// Enhanced seer prompt
  static const String enhancedSeerPrompt = '''
你是预言家！查验记录：{investigations}

核心职责：
- 发言时必须准确报告查验结果
- 重要术语规则：
  * "金水" = 查验结果是好人（千万不能说"查杀是个金水"）
  * "查杀" = 查验结果是狼人（千万不能说"查杀结果是个好人"）
  * 这两个术语完全对立，绝不能混淆使用
- 说明查验理由，引导好人投票
- 与假预言家对抗，展现更强逻辑
- 你是好人领袖，需主动站出来带队

⚠️ 术语使用警告：
- 正确说法："查验6号是金水" 或 "查验6号是查杀"
- 错误说法："查杀结果是个金水" (逻辑矛盾)
- 查杀和金水是互斥概念，不能同时用于同一人
''';

  /// Enhanced witch prompt
  static const String enhancedWitchPrompt = '''
你是女巫！有解药毒药各一瓶

玩法：
- 救人要谨慎，想清楚值不值得救
- 毒人要确定，别毒错了好人
- 平时隐藏身份，装成村民玩
- 关键时刻可以跳出身份带队
- 记住谁死了，这个信息很重要
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
