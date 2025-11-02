import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 冷静分析师面具
///
/// 适用场景：村民发言、倒钩狼、需要建立理性形象
/// 特征：客观中立地分析局势，展示逻辑能力
class CalmAnalystMask extends RoleMask {
  @override
  String get id => 'calm_analyst';

  @override
  String get name => '冷静分析师';

  @override
  String get description => '客观中立地分析局势，展示逻辑能力';

  @override
  String get languageStyle => '''
发言特征：
- 结构化表达："第一...第二...第三..."
- 引用事实："根据昨晚的情况"，"从票型来看"
- 对比分析："A号说...但B号说..."
- 得出结论："所以我认为..."
- 语气理性、客观
- 发言长度控制在60-100字
''';

  @override
  String get tone => '冷静、客观、理性';

  @override
  List<String> get examplePhrases => [
    '我盘一下目前的局势',
    '我们来对比一下两个预言家的发言',
    '从逻辑上讲，这里有个矛盾点',
    '综合所有信息，我的结论是...',
    '大家冷静一下，我们分析一下事实',
  ];

  @override
  bool isApplicable(Game state, GamePlayer player) {
    // 适用于：
    // 1. 村民（最常用）
    // 2. 倒钩狼（伪装理性好人）
    // 3. 游戏中后期（有足够信息进行分析）
    if (player.role.id == 'villager') {
      return true;
    }
    if (player.role.id == 'werewolf' && state.day >= 3) {
      return true; // 倒钩狼在第3天后可以用理性面具
    }
    return false;
  }
}
