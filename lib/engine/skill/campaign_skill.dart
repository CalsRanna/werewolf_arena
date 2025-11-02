import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 竞选技能 - 决定是否上警竞选警长
class CampaignSkill extends GameSkill {
  @override
  String get id => 'campaign';

  @override
  String get name => '上警竞选';

  @override
  String get description => '决定是否参加警长竞选';

  @override
  String get prompt => '''
现在是警长竞选的上警阶段。你需要决定是否上警竞选警长。

上警的好处：
- 如果当选警长，投票时拥有1.5票的权重
- 可以通过竞选发言展示身份或传递信息
- 死亡时可以通过警徽流传递重要信息

上警的风险：
- 会成为狼人的重点目标
- 需要在竞选发言中表态，可能暴露身份
- 如果表现不佳会被怀疑

请根据你的角色、当前局势和策略，决定是否上警：
- 如果上警，请回复："上警"
- 如果不上警，请回复："不上警"

只需要回复上述两个选项之一即可。
''';
}
