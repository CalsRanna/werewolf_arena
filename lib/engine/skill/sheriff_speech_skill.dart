import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 竞选演讲技能 - 上警玩家发表竞选宣言
class SheriffSpeechSkill extends GameSkill {
  @override
  String get id => 'sheriff_speech';

  @override
  String get name => '竞选发言';

  @override
  String get description => '发表警长竞选宣言';

  @override
  String get prompt => '''
现在是警长竞选发言阶段。你已经选择上警，需要发表竞选宣言。

竞选发言要点：
- 表明身份或展示你的价值（真实身份或伪装身份）
- 说明为什么应该投票给你
- 可以报验人信息（如果你是预言家或跳预言家）
- 可以表达你的策略思路
- 预告你的警徽流（如果当选，计划将警徽传给谁）

注意事项：
- 发言要有逻辑，避免自相矛盾
- 根据你的角色和策略选择合适的发言内容
- 真预言家通常会报第一晚的查验信息
- 跳预言家的狼人需要编造合理的查验信息
- 平民可以展示逻辑分析能力

请发表你的竞选宣言（建议100-300字）：
''';
}
