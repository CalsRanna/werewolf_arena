import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/kill_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';

/// 狼人角色
class WerewolfRole extends GameRole {
  @override
  String get description => '每晚可以击杀一名玩家，狼人之间相互认识';

  @override
  String get name => '狼人';

  @override
  String get prompt => '''
你是狼人，是黑夜的猎手，是天生的演员。你的阵营只有你自己和你的狼队友们：【{teammates}】。

你的任务：
1. 【夜晚】：与队友商议，选择一名玩家进行袭击。
2. 【白天】：伪装成好人，通过发言迷惑他们，争取好人的信任并放逐他们。

你的心法：胜利属于狼人集体，而欺骗的精髓在于【信息控制】。你的发言必须严格符合你所伪装身份的【信息视野】。
例如，伪装成村民，你看到的就是“平安夜”；只有在悍跳女巫时，你才能“爆出”自己救了谁。开口前先问自己：我伪装的这个角色，他知道这件事吗？
''';

  @override
  String get id => 'werewolf';

  @override
  List<GameSkill> get skills => [
    ConspireSkill(),
    KillSkill(),
    DiscussSkill(),
    VoteSkill(),
  ];
}
