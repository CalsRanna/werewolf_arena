import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 狼人刀神职剧本
///
/// 核心思路：通过分析发言，找出并刀杀神职（预言家、女巫、守卫）
class WerewolfKillGodPlaybook extends Playbook {
  @override
  String get id => 'werewolf_kill_god';

  @override
  String get name => '狼人刀神职战术';

  @override
  String get description => '''
核心思路：通过分析发言质量、逻辑能力、身份暴露程度，找出并刀杀神职。
优先级：真预言家 > 女巫 > 守卫 > 发言好的村民。
目标：削弱好人阵营的信息和能力优势。
''';

  @override
  List<String> get applicableRoles => ['werewolf'];

  @override
  bool canActivate(Game state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是狼人
    // 2. 任何阶段都可以使用
    if (player.role.id != 'werewolf') return false;

    return true;
  }

  @override
  String get coreGoal => '精准刀杀神职，削弱好人阵营的信息和能力';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '白天认真听发言，判断谁可能是神职',
      reasoning: '神职通常发言质量高、逻辑清晰、信息准确',
    ),
    PlaybookStep(
      phase: 'day',
      action: '重点关注跳预言家的玩家',
      reasoning: '真预言家是最大威胁，必须优先清除',
    ),
    PlaybookStep(
      phase: 'day',
      action: '注意分析谁可能是女巫（关注刀口、救人、用毒信息）',
      reasoning: '女巫有解药和毒药，是第二威胁',
    ),
    PlaybookStep(
      phase: 'night',
      action: '与狼队友商议，确定刀神职目标',
      reasoning: '统一意见，避免分歧',
    ),
    PlaybookStep(phase: 'night', action: '刀杀确认度最高的神职', reasoning: '优先清除确定的神职'),
    PlaybookStep(
      phase: 'future',
      action: '如果刀到神职，白天表现出"意外"或"分析刀口"',
      reasoning: '不要暴露自己知道对方是神职',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我们分析一下昨晚的刀口',
    '狼人为什么要刀X号？',
    'X号（被刀的神职）可能是因为发言好',
    '我们要注意保护剩余的神职',
    '（狼内讨论）今晚我们刀X号，他很可能是预言家',
  ];

  @override
  List<String> get risks => [
    '预判错误，刀错民当神',
    '守卫守住神职，导致平安夜（暴露刀神意图）',
    '女巫救人或用毒，影响节奏',
    '刀神后好人可能团结，更难混',
  ];

  @override
  String get successCriteria => '成功刀杀关键神职（预言家、女巫），削弱好人阵营';
}
