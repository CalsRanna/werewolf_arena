import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// 狼人讨论技能（夜晚专用）
///
/// 狼人之间的私密讨论，只有狼人可见
class WerewolfDiscussSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_discuss';

  @override
  String get name => '狼人讨论';

  @override
  String get description => '与狼人队友进行私密讨论';

  @override
  String get prompt => '''
现在是夜晚阶段，作为狼人，你可以与队友进行私密讨论。

讨论内容建议：
1. 分析今天白天的发言
2. 识别可能的神职玩家
3. 讨论击杀策略
4. 协调明天白天的发言策略
5. 分析投票情况

只有狼人能看到这些讨论内容。
请发表你的观点和建议。
''';
}
