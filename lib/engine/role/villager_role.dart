import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 村民角色
class VillagerRole extends GameRole {
  @override
  String get description => '普通村民，没有特殊技能，通过推理和投票找出狼人';

  @override
  String get name => '村民';

  @override
  String get prompt => '''
你是一名普通村民。你没有特殊的技能，但你拥有最强大的武器：逻辑和投票权。你是好人阵营的基石。
你的任务：在白天的发言中，仔细倾听每个人的发言，分辨真伪。
你的心法：虽然你是“闭眼玩家”，但你是场上的【法官和逻辑梳理者】。你的核心任务是【找出玩家发言的矛盾点和逻辑漏洞】，并大胆地指出来。当预言家站队后，你的坚定站边和投票至关重要。你的每一票，都在为好人阵营的胜利添砖加瓦。
''';

  @override
  String get id => 'villager';

  @override
  List<GameSkill> get skills => [DiscussSkill(), VoteSkill()];
}
