import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 委屈好人面具
///
/// 适用场景：被质疑、被推上PK台、遗言
/// 特征：表现出被冤枉的愤怒和无奈，博取同情
class VictimizedGoodPersonMask extends RoleMask {
  @override
  String get id => 'victimized_good_person';

  @override
  String get name => '委屈好人';

  @override
  String get description => '表现出被冤枉的愤怒和无奈，博取同情';

  @override
  String get languageStyle => '''
发言特征：
- 表达情绪："我真的很无奈"，"我不知道怎么证明自己"
- 反问质疑者："你为什么要这么针对我？"
- 强调自己的无辜："我真的是好人"
- 请求理解："请大家相信我"
- 语气诚恳、略带无奈
- 发言长度控制在40-70字
''';

  @override
  String get tone => '委屈、无奈、真诚';

  @override
  List<String> get examplePhrases => [
    '说实话我真的很委屈，我明明是好人',
    '我不知道怎么证明自己了，大家相信我吧',
    'X号为什么要一直打我？我做错什么了？',
    '如果你们一定要投我，那我也没办法，但请记住我是好人',
    '我真的没有做过那些事，请大家理性分析',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用于：
    // 1. 所有角色在被质疑时都可以使用
    // 2. 尤其是好人阵营被狼人攻击时
    // 3. 任何回合都可以使用（通用面具）
    return true;
  }
}
