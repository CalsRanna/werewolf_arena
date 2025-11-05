import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 女巫/猎人避让警徽战术剧本
///
/// 核心思路：女巫和猎人通常不上警，避免成为狼人刀口，
/// 潜伏在后置位发挥关键作用
class WitchHunterAvoidSheriffPlaybook extends Playbook {
  @override
  String get id => 'witch_hunter_avoid_sheriff';

  @override
  String get name => '女巫/猎人避让警徽战术';

  @override
  String get description => '''
核心思路：女巫和猎人拥有关键技能，不应该上警竞选，避免成为狼人的优先击杀目标。
应该低调潜伏，在后置位观察局势，在关键时刻发挥作用。
成功关键：不要暴露身份，保持低调，投票支持真预言家拿警徽。
''';

  @override
  List<String> get applicableRoles => ['witch', 'hunter'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是女巫或猎人
    // 2. 第1天
    // 3. 还没有警长
    if (player.role.id != 'witch' && player.role.id != 'hunter') return false;
    if (state.day != 1) return false;
    if (state.sheriff != null) return false;

    return true;
  }

  @override
  String get coreGoal => '不上警，避免成为狼人刀口，潜伏观察局势';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'campaign',
      action: '果断选择不上警',
      reasoning: '女巫和猎人的技能太关键，不能过早暴露，上警容易成为狼人刀口',
    ),
    PlaybookStep(
      phase: 'day',
      action: '在讨论阶段低调发言，不要暴露身份',
      reasoning: '保持隐蔽，在关键时刻才发挥作用',
      exampleSpeech: [
        '我选择不上警，想听听大家的发言',
        '我会在后置位观察局势',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_vote',
      action: '投票给真预言家',
      reasoning: '帮助真预言家拿到警徽，为好人阵营建立优势',
    ),
    PlaybookStep(
      phase: 'night',
      action: '女巫保留技能，猎人准备好关键时刻开枪',
      reasoning: '不要浪费关键技能，等待最佳使用时机',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我选择不上警',
    '我想在后置位观察',
    '上警的人里应该有预言家',
    '我会投票给最像预言家的人',
    '保持低调，听听大家怎么说',
  ];

  @override
  List<String> get risks => [
    '如果真预言家也不上警，警徽可能被狼人抢走',
    '不上警可能被认为是狼人',
    '投票给错误的人会被质疑',
  ];

  @override
  String get successCriteria => '成功避让警徽，保持身份隐蔽，帮助真预言家拿到警徽';
}
