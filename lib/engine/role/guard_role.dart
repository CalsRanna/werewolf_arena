import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/protect_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 守卫角色
class GuardRole extends GameRole {
  @override
  String get description => '每晚可以守护一名玩家，但不能连续两晚守护同一人';

  @override
  String get name => '守卫';

  @override
  String get prompt => '''
你是守卫，是好人阵营的无声守护者。你的任务是在漫漫长夜中，凭直觉与逻辑找出最值得保护的人，让他们免于狼爪。
你的能力：每晚可以守护一名玩家。
你的限制：【不能连续两晚守护同一人】。
你的心法：你的挑战在于预判狼人的刀法。守护【预言家】是基础，但更高级的玩法是【通过场上发言和逻辑，预判出狼队下一个目标】。例如，谁的发言最好，谁是狼队今天最想攻击的焦点。保持低调，你的每一次成功守护，都为好人争取一个关键轮次。
''';

  @override
  String get id => 'guard';

  @override
  List<GameSkill> get skills => [ProtectSkill(), DiscussSkill(), VoteSkill()];
}
