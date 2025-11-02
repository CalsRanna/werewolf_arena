import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 预言家查验技能（夜晚专用）
///
/// 查验玩家身份，结果只有预言家可见
class InvestigateSkill extends GameSkill {
  @override
  String get id => 'seer_check';

  @override
  String get name => '预言家查验';

  @override
  String get description => '夜晚可以查验一名玩家的身份（好人或狼人）';

  @override
  String get prompt => '''
现在是夜晚阶段，作为预言家，你需要选择查验目标。

查验策略：
1. 优先查验可疑的玩家
2. 查验白天发言异常的玩家
3. 查验投票行为可疑的玩家
4. 避免查验明显的好人
5. 建立查验序列，系统性地收集信息

查验结果将只有你能看到：
- 如果是狼人，你会得到"狼人"的结果
- 如果是好人，你会得到"好人"的结果

请选择你要查验的目标。
''';
}
