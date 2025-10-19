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
你的能力：当你死亡时（【注意：仅限于被狼人夜晚杀死或被白天公投出局】），你可以发动技能，选择场上任意一名存活玩家与你一同出局。
你的限制：如果你是被女巫毒死的，你不能发动技能。
你的心法：你是一张强大的威慑牌。你可以高调地表明身份，让狼人不敢在白天攻击你。你的最后一枪至关重要，务必在死前理清逻辑，带走你最怀疑的那个狼人。要么不开枪，开枪就要见血封喉！
''';

  @override
  String get id => 'hunter';

  @override
  List<GameSkill> get skills => [ShootSkill(), DiscussSkill(), VoteSkill()];
}
