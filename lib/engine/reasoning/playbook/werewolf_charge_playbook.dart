import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 狼人冲锋剧本
///
/// 核心思路：在局势劣势或优势明显时，狼人放弃伪装，直接冲锋
class WerewolfChargePlaybook extends Playbook {
  @override
  String get id => 'werewolf_charge';

  @override
  String get name => '狼人冲锋战术';

  @override
  String get description => '''
核心思路：当狼队优势明显（人数接近或狼人多），或者劣势无法翻盘时，放弃伪装直接冲锋。
适用场景：
1. 优势局：狼人数量接近好人，可以强推票
2. 劣势局：被多人指认，与其防守不如冲锋带走关键好人
''';

  @override
  List<String> get applicableRoles => ['werewolf'];

  @override
  bool canActivate(Game state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是狼人
    // 2. 游戏第3天以后（前期不适合冲锋）
    if (player.role.id != 'werewolf') return false;
    if (state.day < 3) return false;

    // 未来优化：判断场上人数比例，狼人是否优势
    return true;
  }

  @override
  String get coreGoal => '放弃伪装，利用人数或票数优势强推关键好人出局';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '评估局势：狼队是否有人数优势或票数优势',
      reasoning: '冲锋需要能控票，否则会加速失败',
    ),
    PlaybookStep(
      phase: 'day',
      action: '选定冲锋目标：预言家、女巫等关键神职',
      reasoning: '冲锋要有价值，换掉关键角色',
    ),
    PlaybookStep(
      phase: 'day',
      action: '发言中明确表态：今天必须出X号',
      reasoning: '冲锋就是要坚决，不留余地',
    ),
    PlaybookStep(
      phase: 'day',
      action: '与狼队友配合，集中火力攻击目标',
      reasoning: '狼队团结才能冲锋成功',
    ),
    PlaybookStep(phase: 'vote', action: '所有狼人集中投票给目标', reasoning: '确保目标出局'),
    PlaybookStep(
      phase: 'future',
      action: '如果冲锋成功，继续推进；如果失败，接受被出局',
      reasoning: '冲锋是破釜沉舟，成败在此一举',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '今天我们必须出X号',
    '我不管你们怎么想，我票定了X号',
    'X号（神职）不出，我们（好人）就输了',
    '我认为场上局势很明确了',
    '我们不能再犹豫，今天就是X号',
  ];

  @override
  List<String> get risks => [
    '人数优势不足，冲锋失败自己被票',
    '狼队友没有配合，导致冲锋失败',
    '好人意识到冲锋，迅速团结反击',
    '冲锋暴露狼队，后续难以翻盘',
  ];

  @override
  String get successCriteria => '成功推出关键神职，利用人数优势赢得游戏';
}
