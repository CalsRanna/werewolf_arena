import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// 猎人开枪技能（死亡时触发）
///
/// 猎人死亡时可以开枪带走一名玩家，但被毒死时不能开枪
class ShootSkill extends GameSkill {
  @override
  String get skillId => 'hunter_shoot';

  @override
  String get name => '猎人开枪';

  @override
  String get description => '猎人死亡时可以开枪带走一名玩家（被毒除外）';

  @override
  String get prompt => '''
你是猎人，刚刚死亡。现在你可以使用你的猎枪带走一名玩家。

开枪策略：
1. 优先击杀已确认的狼人
2. 击杀最可疑的玩家
3. 考虑击杀对好人阵营威胁最大的玩家
4. 避免击杀已确认的好人
5. 如果不确定，可以选择最可疑的发言者

这是你为好人阵营做出的最后贡献，请谨慎选择。
你的决定可能影响游戏的最终结果。

请选择你要射杀的目标：
''';
}
