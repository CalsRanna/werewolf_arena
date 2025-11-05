import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 村民假冲锋剧本
///
/// 核心思路：村民假装神职（如假跳预言家），吸引狼人刀自己，保护真神职
class VillagerBlockKnifePlaybook extends Playbook {
  @override
  String get id => 'villager_block_knife';

  @override
  String get name => '村民假冲锋战术';

  @override
  String get description => '''
核心思路：村民假装自己是神职（如预言家），吸引狼人刀自己，保护真神职。
适用场景：真预言家还没跳，或者神职已经暴露需要保护。
风险：可能误导好人阵营，需要谨慎使用。
''';

  @override
  List<String> get applicableRoles => ['villager'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是村民
    // 2. 第2-3天（有一定信息，但不能太晚）
    if (player.role.id != 'villager') return false;
    if (state.day < 2 || state.day > 3) return false;

    return true;
  }

  @override
  String get coreGoal => '用村民身份吸引狼刀，保护真正的神职';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '观察场上是否有真预言家跳出',
      reasoning: '如果真预言家还没跳，可以假跳吸引狼刀',
    ),
    PlaybookStep(
      phase: 'day',
      action: '如果真预言家已跳，可以表现得像女巫或守卫',
      reasoning: '暗示自己是神职，让狼人犹豫',
    ),
    PlaybookStep(
      phase: 'day',
      action: '发言中带有神职视角，但不明确说身份',
      reasoning: '例如："我觉得我们要保护好神职"（暗示自己是神）',
    ),
    PlaybookStep(
      phase: 'day',
      action: '表现出对局势的深刻理解',
      reasoning: '让狼人觉得你是威胁，优先刀你',
    ),
    PlaybookStep(
      phase: 'future',
      action: '如果被刀，遗言中说明自己是村民假冲锋',
      reasoning: '告诉好人真相，避免误导',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我有些信息想和大家分享',
    '从我的角度来看...',
    '我觉得我们应该重点关注X号',
    '今晚如果我被刀了，请好人...',
    '（遗言）我是村民，假冲锋吸引狼刀，请好人理解',
  ];

  @override
  List<String> get risks => [
    '可能误导好人，让好人以为你是神职',
    '真神职可能因为你假跳而不敢跳',
    '狼人可能看穿假冲锋，反而不刀你',
    '如果没被刀，后续很难解释',
  ];

  @override
  String get successCriteria => '成功吸引狼刀，让真神职多存活一晚，为好人阵营提供更多信息';
}
