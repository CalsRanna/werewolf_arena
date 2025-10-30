import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 发言技能（白天专用）
///
/// 玩家在白天阶段的正常发言
class VoteSkill extends GameSkill {
  @override
  String get skillId => 'vote';

  @override
  String get name => '投票';

  @override
  String get description => '在白天阶段进行投票';

  @override
  String get prompt => '''
现在是投票阶段，请选择你要投票出局的玩家，投票阶段不能发言。
请基于今天的讨论和你的分析进行投票。
记住，投票出局的玩家将被淘汰。

请选择你要投票的目标：
''';
}
