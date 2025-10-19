import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 守卫保护技能（夜晚专用）
///
/// 包含守护规则：不能连续两晚守护同一人
class ProtectSkill extends GameSkill {
  @override
  String get skillId => 'guard_protect';

  @override
  String get name => '守卫保护';

  @override
  String get description => '夜晚可以守护一名玩家，保护其免受狼人击杀';

  @override
  String get prompt => '''
现在是夜晚阶段，作为守卫，你需要选择守护目标。

守护规则：
- 你不能连续两晚守护同一名玩家
- 守护可以保护玩家免受狼人击杀
- 如果你守护的玩家被狼人击杀，他们将存活

策略建议：
1. 优先保护可能的神职玩家
2. 观察白天谁的发言最有价值
3. 考虑狼人的击杀偏好
4. 必要时可以守护自己（除非昨晚已守护）
5. 避免守护明显的村民

请选择你要守护的目标。
''';
}
