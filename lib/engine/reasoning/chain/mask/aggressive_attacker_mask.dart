import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 激进攻击者面具
///
/// 适用场景：狼人主动打人、制造节奏、转移注意力
/// 特征：主动攻击他人，质疑对手，节奏带动
class AggressiveAttackerMask extends RoleMask {
  @override
  String get id => 'aggressive_attacker';

  @override
  String get name => '激进攻击者';

  @override
  String get description => '主动攻击他人，质疑对手，带动节奏';

  @override
  String get languageStyle => '''
发言特征：
- 直接质疑其他玩家："X号的发言有很大问题"
- 指出矛盾："你前面说...现在又说..."
- 制造压迫感："你解释一下为什么..."
- 带动节奏："我建议大家注意X号"
- 语气强硬但不失理性
- 发言长度控制在50-80字
''';

  @override
  String get tone => '强硬、质疑、进攻性';

  @override
  List<String> get examplePhrases => [
    'X号的发言很有问题，他前面说的和现在完全矛盾',
    '我要点一下X号，你能解释一下你的逻辑吗？',
    '大家注意X号，他从头到尾都在带节奏',
    '这个发言完全站不住脚，明显有问题',
    'X号你在紧张什么？好人不会这么说话',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用于：
    // 1. 狼人在任何阶段都可以使用（主动攻击策略）
    // 2. 好人在确定狼人身份后也可以使用
    // 3. 游戏第2天以后（有足够信息支撑攻击）
    if (player.role.id == 'werewolf') {
      return true; // 狼人随时可用
    }
    if (state.day >= 2) {
      // 其他角色在中后期可以使用
      return true;
    }
    return false;
  }
}
