import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 甩锅者面具
///
/// 适用场景：被质疑时转移注意力、狼人反咬
/// 特征：将怀疑转移到其他玩家身上
class ScapegoaterMask extends RoleMask {
  @override
  String get id => 'scapegoater';

  @override
  String get name => '甩锅者';

  @override
  String get description => '将怀疑和注意力转移到其他玩家身上';

  @override
  String get languageStyle => '''
发言特征：
- 转移焦点："比起我，你们不觉得X号更可疑吗？"
- 反问质疑者："你为什么不去看X号？"
- 对比："我只是...但X号..."
- 制造新的怀疑目标："大家应该注意X号"
- 语气防御性强但试图转攻为守
- 发言长度控制在40-70字
''';

  @override
  String get tone => '防御、转移、反击';

  @override
  List<String> get examplePhrases => [
    '比起质疑我，你们为什么不看看X号？他的问题更大',
    '我觉得你们的注意力放错地方了，X号才是关键',
    '如果我是狼，我会像X号那样做吗？',
    '你一直盯着我，是不是想保护X号？',
    '与其在我身上浪费时间，不如看看X号的逻辑',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用于：
    // 1. 狼人被质疑时反咬（最常用）
    // 2. 任何角色被质疑时都可以使用
    // 3. 任何阶段都可使用
    return true; // 通用防御面具
  }
}
