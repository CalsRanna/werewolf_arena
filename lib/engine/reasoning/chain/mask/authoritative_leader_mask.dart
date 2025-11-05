import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 强势领袖面具
///
/// 适用场景：预言家起跳、狼人悍跳、关键投票轮
/// 特征：用不容置疑的语气带领团队，定义谁是狼谁是好人
class AuthoritativeLeaderMask extends RoleMask {
  @override
  String get id => 'authoritative_leader';

  @override
  String get name => '强势领袖';

  @override
  String get description => '用不容置疑的语气带领团队，定义谁是狼谁是好人';

  @override
  String get languageStyle => '''
发言特征：
- 使用肯定句，避免"可能"、"也许"等模糊词
- 使用命令式："今天我们出X号"，"好人跟我来"
- 直接定义身份："X号就是狼"，"Y号一定是好人"
- 简洁有力，每句话都斩钉截铁
- 发言长度控制在50-80字
''';

  @override
  String get tone => '权威、坚定、不容置疑';

  @override
  List<String> get examplePhrases => [
    '听我的，今天必须出X号',
    'X号就是狼，没有任何疑问',
    '好人跟我票，我们今天拿下狼人',
    '我不接受任何质疑，我的逻辑已经很清楚了',
    '今天不出X号，明天后悔就晚了',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用于：
    // 1. 预言家/狼人在起跳或对跳场景
    // 2. 游戏第2天以后（有足够信息支撑强势）
    // 3. 关键投票轮次
    if (state.day >= 2) {
      // 预言家和狼人在中后期都可以使用强势领袖
      if (player.role.id == 'seer' || player.role.id == 'werewolf') {
        return true;
      }
    }
    return false;
  }
}
