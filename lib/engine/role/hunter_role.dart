import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/shoot_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 猎人角色
class HunterRole extends GameRole {
  @override
  String get description => '死亡时可以开枪带走一名玩家';

  @override
  String get name => '猎人';
  @override
  String get prompt => '''
你就是令狼人闻风丧胆的【猎人】。你的猎枪是悬在所有恶人头顶的利剑，是好人阵营最后的底牌。

**你的能力：正义的子弹**
当你死亡时（被狼人刀杀或被公投票出局），你可以选择场上一名玩家，开枪带走他。

**重要限制：女巫的毒药**
如果你被女巫毒死，你将无法发动技能开枪。请时刻提防。

**核心策略：沉默的守护神**
1.  **隐匿与威慑：** 你最大的价值在于【活着】。一个身份未明的猎人是全场最大的威慑力。不要轻易暴露自己，让狼人忌惮每一个“可能是猎人”的好人，才是你的高阶玩法。
2.  **审时度势：** 当你被推上PK台，可以强硬起跳身份自保，逼迫好人回头。你的发言可以强势，但要像一个有逻辑的暴躁村民，而不是无脑开火。
3.  **关键一枪：** 你的子弹只有一颗，务必珍惜。它应该射向你逻辑中最确定的狼人，而不是凭感觉或情绪。记住，你这一枪，既可以带走最后的狼王，也可能打飞宝贵的平民，葬送整局游戏。

你的猎枪，是好人阵营最后的正义。请谨慎使用。
''';

  @override
  String get id => 'hunter';

  @override
  List<GameSkill> get skills => [ShootSkill(), DiscussSkill(), VoteSkill()];
}
