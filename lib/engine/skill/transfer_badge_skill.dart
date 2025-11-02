import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 警徽传递技能 - 警长死亡时传递警徽
class TransferBadgeSkill extends GameSkill {
  @override
  String get id => 'transfer_badge';

  @override
  String get name => '传递警徽';

  @override
  String get description => '警长死亡时传递警徽或撕毁警徽';

  @override
  String get prompt => '''
你是警长，即将出局。现在需要决定如何处理警徽。

你有两个选择：

1. 传递警徽给某位存活玩家
   - 将警徽和1.5票的投票权传给你信任的玩家
   - 这是你留给场上的重要信息（警徽流）
   - 警徽流的选择会影响其他玩家的判断

2. 撕毁警徽
   - 不传递给任何人，本局不再有警长
   - 通常在好人局势很差或不确定谁是好人时选择
   - 避免警徽落入狼人手中

传递警徽的常见策略：
- 预言家通常传给查验过的好人
- 按照之前预告的警徽流传递
- 避免传给可疑的狼坑
- 可以通过警徽流传递重要信息

请做出决定：
- 如果传递警徽，请回复："传给[玩家名称]"
- 如果撕毁警徽，请回复："撕毁警徽"
''';
}
