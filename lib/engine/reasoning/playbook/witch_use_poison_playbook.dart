import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 女巫用毒剧本
///
/// 核心思路：在确认狼人身份后果断用毒，帮助好人阵营减员
class WitchUsePoisonPlaybook extends Playbook {
  @override
  String get id => 'witch_use_poison';

  @override
  String get name => '女巫用毒战术';

  @override
  String get description => '''
核心思路：在确认狼人身份后（预言家查杀、逻辑推断、或多人指认）果断用毒。
用毒时机：通常在第2-3天，有足够信息判断后。
注意：不要轻易用毒，一旦用错会帮倒忙。
''';

  @override
  List<String> get applicableRoles => ['witch'];

  @override
  bool canActivate(GameState state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是女巫
    // 2. 第2天或之后（有足够信息）
    // 3. 毒药还在（未来优化：需要追踪药品状态）
    if (player.role.id != 'witch') return false;
    if (state.day < 2) return false;

    return true;
  }

  @override
  String get coreGoal => '找到确定的狼人并用毒药毒死，帮助好人阵营快速减员';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '白天认真听发言，分析谁最可能是狼人',
      reasoning: '用毒需要高确信度，不能随便用',
    ),
    PlaybookStep(
      phase: 'day',
      action: '重点关注预言家的查杀、逻辑矛盾、狼队配合',
      reasoning: '这些是判断狼人身份的关键信息',
    ),
    PlaybookStep(
      phase: 'day',
      action: '如果有预言家查杀，且查杀目标发言不好，确定用毒',
      reasoning: '预言家查杀+发言差=高确信度狼人',
    ),
    PlaybookStep(
      phase: 'night',
      action: '晚上果断对目标使用毒药',
      reasoning: '及时清除狼人，加速好人胜利',
    ),
    PlaybookStep(
      phase: 'future',
      action: '第二天可以跳女巫公布用毒信息，建立信任',
      reasoning: '跳女巫+正确用毒=高可信度好人',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我觉得X号很可能是狼，逻辑完全不通',
    'X号昨天被预言家查杀，今天发言也很差',
    '如果有女巫的话，建议毒X号',
    '（用毒后）昨晚我是女巫，我毒了X号',
    '我用毒是因为...（给出充分理由）',
  ];

  @override
  List<String> get risks => [
    '可能毒错人（如预言家是假的，或者被狼人误导）',
    '用毒后身份暴露，容易被狼人针对',
    '过早用毒，后面可能有更明确的狼人',
  ];

  @override
  String get successCriteria => '成功毒死狼人，并通过用毒信息建立女巫身份的可信度';
}
