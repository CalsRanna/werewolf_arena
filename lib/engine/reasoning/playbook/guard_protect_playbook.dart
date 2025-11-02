import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 守卫守护剧本
///
/// 核心思路：通过分析场上信息，守护最可能被刀的关键好人
class GuardProtectPlaybook extends Playbook {
  @override
  String get id => 'guard_protect';

  @override
  String get name => '守卫守护战术';

  @override
  String get description => '''
核心思路：分析局势，守护最可能被狼人刀杀的关键好人（预言家、女巫等）。
关键：理解狼人思路，预判狼刀目标。
注意：不能连续两晚守同一人。
''';

  @override
  List<String> get applicableRoles => ['guard'];

  @override
  bool canActivate(Game state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是守卫
    // 2. 任何时候都可以使用
    if (player.role.id != 'guard') return false;

    return true;
  }

  @override
  String get coreGoal => '守护关键好人，防止狼人刀杀，延长好人存活时间';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '白天认真听发言，找出谁是预言家、女巫等关键神职',
      reasoning: '知道谁是神职，才能有效守护',
    ),
    PlaybookStep(
      phase: 'day',
      action: '分析狼人可能的刀人策略',
      reasoning: '预判狼刀目标：跳预言家的？发言好的？威胁大的？',
    ),
    PlaybookStep(
      phase: 'night',
      action: '第一晚守护发言位置靠前或最优秀的玩家',
      reasoning: '第一晚信息少，守高威胁玩家',
    ),
    PlaybookStep(
      phase: 'night',
      action: '第二晚及以后，守护已确认的预言家或关键神职',
      reasoning: '真预言家是狼人首要目标',
    ),
    PlaybookStep(
      phase: 'day',
      action: '如果守成功（平安夜），暗自分析原因',
      reasoning: '守成功说明预判正确，可以继续这个思路',
    ),
    PlaybookStep(
      phase: 'day',
      action: '低调发言，不要暴露守卫身份',
      reasoning: '守卫身份暴露后容易被刀',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我觉得X号（预言家）的发言很有道理',
    '我们要保护好神职',
    '狼人应该会刀发言好的人',
    '大家注意保护关键信息位',
    '（守成功后）昨晚平安夜，可能守卫守成功了',
  ];

  @override
  List<String> get risks => [
    '预判错误，守错人导致关键神职被刀',
    '狼人屠边（刀民），不刀神职，守卫价值降低',
    '暴露身份后容易被狼人针对',
    '同一人不能连守，第二晚可能守不了',
  ];

  @override
  String get successCriteria => '成功守护关键神职，防止好人阵营重要成员被刀';
}
