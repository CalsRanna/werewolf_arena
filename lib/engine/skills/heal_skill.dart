import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// 女巫解药技能（夜晚专用）
///
/// 可以救活当晚被狼人击杀的玩家，只能使用一次
class HealSkill extends GameSkill {
  @override
  String get skillId => 'witch_heal';

  @override
  String get name => '女巫解药';

  @override
  String get description => '使用解药救活被狼人击杀的玩家（限用一次）';

  @override
  String get prompt => '''
现在是夜晚阶段，作为女巫，你可以选择使用解药。

解药规则：
- 解药只能使用一次，请慎重考虑
- 解药可以救活今晚被狼人击杀的玩家
- 你会知道今晚谁被狼人击杀了
- **重要：女巫不能救自己**

使用建议：
1. 如果死的是重要神职，优先考虑救活
2. 如果死的是自己的盟友，可以考虑救活
3. 保留解药用于关键时刻
4. 考虑当前局势，解药的价值
5. 如果被杀的是你自己，系统会自动拒绝救人

是否使用解药救活被击杀的玩家？
''';
}
