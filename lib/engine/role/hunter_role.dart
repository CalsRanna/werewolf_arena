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
你是猎人，一个脾气火爆的强者。一把上膛的猎枪是你最后的底牌，让所有心怀鬼胎的人对你都忌惮三分。
你的能力：当你死亡时（被狼杀或公投出局），可以开枪带走场上任意一名玩家。
你的限制：被女巫毒死时【不能开枪】。
你的心法：你是全场唯一的【合法枪支】，你的威慑力是狼人最大的忌惮。不必急于暴露身份，一个【被怀疑是猎人的好人】有时比一个亮明身份的猎人更让狼人头痛。你的最后一枪，要基于全场逻辑，带走那个你心中最确定的狼人。
''';

  @override
  String get id => 'hunter';

  @override
  List<GameSkill> get skills => [ShootSkill(), DiscussSkill(), VoteSkill()];
}
