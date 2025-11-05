import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 狼人悍跳预言家战术剧本
///
/// 核心思路：抢在真预言家之前或同时跳出，
/// 用强势的气场和编造的查验结果争夺话语权
class WerewolfJumpSeerPlaybook extends Playbook {
  @override
  String get id => 'werewolf_jump_seer';

  @override
  String get name => '狼人悍跳预言家战术';

  @override
  String get description => '''
核心思路：抢在真预言家之前或同时跳出，用强势的气场和编造的查验结果争夺话语权。
成功关键：发言要坚定自信，逻辑要自洽，查验结果要合理。
''';

  @override
  List<String> get applicableRoles => ['werewolf'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是狼人
    // 2. 第1-2天
    // 3. 预言家还没跳出来（或刚跳出来）
    if (player.role.id != 'werewolf') return false;
    if (state.day > 2) return false;

    // 未来优化：检查WorkingMemory中是否已有预言家跳出
    // 简化实现：前2天都可以使用此战术
    return true;
  }

  @override
  String get coreGoal => '通过悍跳预言家身份，争夺场上话语权，误导好人阵营';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '第一个或第二个发言时，立刻宣布自己是预言家',
      reasoning: '抢占先机，给真预言家造成压力',
    ),
    PlaybookStep(
      phase: 'day',
      action: '公布一个合理的查验结果：给真预言家发查杀，或给好人发金水',
      reasoning: '查杀真预言家能直接对决；发金水能建立信任',
    ),
    PlaybookStep(
      phase: 'day',
      action: '给出警徽流（验人计划）',
      reasoning: '增加可信度，像真预言家一样规划',
    ),
    PlaybookStep(
      phase: 'day',
      action: '如果真预言家跳出来，立刻攻击他的逻辑漏洞',
      reasoning: '不能让真预言家站稳脚跟',
    ),
    PlaybookStep(
      phase: 'vote',
      action: '带队投票给真预言家或其金水',
      reasoning: '推出真预言家是最大胜利',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我是真预言家',
    '昨晚我验了X号',
    '他是查杀/金水',
    '我的警徽流是...',
    'X号（真预言家）明显是悍跳狼',
    '好人相信我，今天先出X号',
    '我不会让狼人得逞的',
  ];

  @override
  List<String> get risks => [
    '真预言家发言质量高，好人可能站边真预言家',
    '查验结果可能与其他信息冲突（如女巫知道刀口）',
    '狼队友配合不到位，暴露破绽',
  ];

  @override
  String get successCriteria => '成功推出真预言家，或至少让好人阵营分裂站边';
}
