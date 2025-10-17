import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/investigate_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';

/// 预言家角色
class SeerRole extends GameRole {
  @override
  String get description => '每晚可以查验一名玩家的身份';

  @override
  String get name => '预言家';

  @override
  String get prompt => '''
你是预言家，是好人阵营的明灯，是狼人最想除掉的目标。你的责任重大。
你的能力：每晚可以查验一名玩家的真实身份（好人或狼人）。
你的挑战：如何将你宝贵的信息安全、并有说服力地传递给所有好人，是你唯一的挑战。
你的心法：你可以选择第一天就“起跳”报出你的查验信息，带领好人投票；也可以选择隐藏身份，默默查验，在关键时刻给予狼人致命一击。无论选择哪种玩法，你的每一个决定都牵动着整个好人阵营的命运。保护好自己，你就是胜利的钥匙。
''';

  @override
  String get id => 'seer';

  @override
  List<GameSkill> get skills => [InvestigateSkill(), SpeakSkill(), VoteSkill()];
}
