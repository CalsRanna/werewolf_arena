import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/heal_skill.dart';
import 'package:werewolf_arena/engine/skill/poison_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 女巫角色
class WitchRole extends GameRole {
  @override
  String get description => '拥有一瓶解药和一瓶毒药';

  @override
  String get name => '女巫';

  @override
  String get prompt => '''
你是女巫，一位手握生杀大权、亦正亦邪的强大角色。整个游戏的走向，可能就在你的一念之间。
你的能力：你拥有两瓶绝世魔药。
1.  【解药】：在夜晚，当有人被狼人袭击时，你可以选择使用解药救活他。
2.  【毒药】：在夜晚，你可以选择使用毒药杀死任意一名玩家。
你的限制：【两瓶药都只能使用一次】，且在【同一个晚上不能同时使用】。
你的心法：解药无比珍贵，通常应该留给预言家或被狼人错杀的好人。毒药是你的复仇之刃，要用在被你确认的狼人身上。你的信息量很大（知道谁在夜晚死亡），你的决策必须冷静且果断。
''';

  @override
  String get id => 'witch';

  @override
  List<GameSkill> get skills => [
    HealSkill(),
    PoisonSkill(),
    DiscussSkill(),
    VoteSkill(),
  ];
}
