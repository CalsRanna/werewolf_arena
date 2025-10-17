import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/protect_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';

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
你的限制：【不能连续两晚守护同一个人】。
你的心法：你的挑战在于预判狼人的刀法。预言家是你的首要守护对象，但如果预言家隐藏得很好，一个发言出色的村民或另一个你怀疑是神职的玩家也值得你用生命去守护。保持低调，你的每一次成功守护，都是对狼人计划的致命打击。
''';

  @override
  String get id => 'guard';

  @override
  List<GameSkill> get skills => [ProtectSkill(), SpeakSkill(), VoteSkill()];
}
