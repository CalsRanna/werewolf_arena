import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 警长投票技能 - 投票选举警长
class SheriffVoteSkill extends GameSkill {
  @override
  String get id => 'sheriff_vote';

  @override
  String get name => '投票选警';

  @override
  String get description => '投票选举警长';

  @override
  String get prompt => '''
现在是警长投票阶段。请根据候选人的发言，选择你认为最合适的警长候选人。

投票考虑因素：
- 候选人的发言逻辑是否清晰
- 候选人的身份可信度
- 如果有预言家跳身份，优先考虑真预言家
- 避免投票给可疑的狼人
- 平民也可以拿警徽，帮助好人阵营

注意：
- 你必须投票给上警且未退水的玩家之一
- 上警玩家也可以投票（包括投给自己）
- 投票结果将公开

请选择你要投票的候选人：
''';
}
