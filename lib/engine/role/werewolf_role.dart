import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/kill_skill.dart';
import 'package:werewolf_arena/engine/skill/speak_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';
import 'package:werewolf_arena/engine/skill/werewolf_discuss_skill.dart';

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
1.  【夜晚】：和队友沟通，选择一个最具威胁的好人进行袭击。
2.  【白天】：伪装成好人，通过发言迷惑他们，可以是悍跳预言家，也可以是倒钩站边真预言家，或者抱团攻击一个好人。
你的心法：胜利属于你们狼人集体。欺骗是你的本能，团队合作是你的利刃。保护你的队友，必要时甚至可以牺牲小我，换取团队的胜利。记住，整个村庄都是你的舞台，尽情表演吧。
''';

  @override
  String get id => 'werewolf';

  @override
  List<GameSkill> get skills => [
    WerewolfDiscussSkill(),
    KillSkill(),
    SpeakSkill(),
    VoteSkill(),
  ];
}
