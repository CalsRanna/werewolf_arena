import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 和事佬面具
///
/// 适用场景：倒钩狼建立好人形象、真正的好人调解矛盾
/// 特征：缓和矛盾、寻求共识、展现理性温和的形象
class PeacemakerMask extends RoleMask {
  @override
  String get id => 'peacemaker';

  @override
  String get name => '和事佬';

  @override
  String get description => '缓和矛盾、寻求共识，建立好人形象';

  @override
  String get languageStyle => '''
发言特征：
- 缓和冲突："大家冷静一下，都听听对方的想法"
- 寻求共识："我们先找找共同点"
- 承认多方观点："X号说得有道理，Y号的角度也不错"
- 提出折中方案："不如我们先..."
- 语气温和、理性、包容
- 发言长度控制在50-80字
''';

  @override
  String get tone => '温和、理性、调解';

  @override
  List<String> get examplePhrases => [
        '大家都别激动，我们理性讨论',
        '我觉得X号和Y号说的都有道理，我们综合考虑一下',
        '现在内讧对好人不利，我们先统一思路',
        '我理解大家的想法，但我们要保持冷静',
        '争论没有意义，我们还是看事实和逻辑',
      ];

  @override
  bool isApplicable(GameState state, GamePlayer player) {
    // 适用于：
    // 1. 倒钩狼建立好人身份（最常用）
    // 2. 真正的好人调解矛盾
    // 3. 游戏中后期更有效（第2天以后）
    if (player.role.id == 'werewolf' && state.day >= 2) {
      return true; // 倒钩狼在中后期建立好人形象
    }
    if ((player.role.id == 'villager' ||
         player.role.id == 'seer' ||
         player.role.id == 'witch' ||
         player.role.id == 'guard') && state.day >= 2) {
      return true; // 好人阵营调解
    }
    return false;
  }
}
