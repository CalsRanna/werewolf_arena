import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 女巫藏药剧本
///
/// 核心思路：第一晚不用解药，保留解药以备后续关键时刻使用
/// 让刀口信息暴露，帮助预言家和好人判断局势
class WitchHideAntidotePlaybook extends Playbook {
  @override
  String get id => 'witch_hide_antidote';

  @override
  String get name => '女巫藏药战术';

  @override
  String get description => '''
核心思路：第一晚不用解药救人，保留解药到关键时刻（如预言家被刀、自己被刀）。
好处：让刀口信息暴露，帮助预言家判断身份；解药可以在更关键的时刻发挥作用。
''';

  @override
  List<String> get applicableRoles => ['witch'];

  @override
  bool canActivate(Game state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是女巫
    // 2. 第1天（首夜）
    // 3. 解药还在（未来优化：需要追踪药品状态）
    if (player.role.id != 'witch') return false;
    if (state.day != 1) return false;

    return true;
  }

  @override
  String get coreGoal => '保留解药到关键时刻，通过刀口信息帮助好人阵营判断局势';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'night',
      action: '第一晚看到刀口后，选择不救',
      reasoning: '保留解药，让刀口信息暴露给场上',
    ),
    PlaybookStep(
      phase: 'day',
      action: '白天观察死者身份和场上反应',
      reasoning: '刀口信息能帮助分析狼人策略',
    ),
    PlaybookStep(
      phase: 'day',
      action: '暗自分析：狼人为什么刀这个人？',
      reasoning: '刀平民说明狼人摸不到神，刀神职说明狼人有信息',
    ),
    PlaybookStep(
      phase: 'day',
      action: '低调发言，不暴露女巫身份',
      reasoning: '女巫不能过早暴露，要保护自己',
    ),
    PlaybookStep(
      phase: 'future',
      action: '在预言家或关键好人被刀时再用解药',
      reasoning: '解药用在关键人物上价值更高',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我觉得昨晚的刀口很有信息',
    '狼人为什么要刀X号？值得思考',
    '这个刀法说明狼人可能...',
    '我不太确定X号的身份，需要观察',
    '大家冷静分析一下刀口',
  ];

  @override
  List<String> get risks => [
    '第一晚被刀的可能是预言家等关键角色',
    '狼人可能连续刀神职，导致解药来不及用',
    '好人可能因为第一晚有死人而怀疑女巫不在',
  ];

  @override
  String get successCriteria => '成功保留解药到关键时刻，并通过刀口信息提供有价值的分析';
}
