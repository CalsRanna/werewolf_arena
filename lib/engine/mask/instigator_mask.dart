import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 煽动者面具
///
/// 适用场景：狼人挑拨离间、制造好人阵营内部矛盾
/// 特征：暗示他人之间的矛盾，制造混乱
class InstigatorMask extends RoleMask {
  @override
  String get id => 'instigator';

  @override
  String get name => '煽动者';

  @override
  String get description => '挑拨离间、制造好人阵营内部矛盾';

  @override
  String get languageStyle => '''
发言特征：
- 暗示矛盾："我发现X号和Y号的说法对不上"
- 制造怀疑："X号一直在保Y号，有点奇怪"
- 放大分歧："X号说的和Y号完全相反"
- 挑拨："你们不觉得X号在带节奏吗？"
- 语气看似客观，实则制造混乱
- 发言长度控制在50-80字
''';

  @override
  String get tone => '挑拨、暗示、制造矛盾';

  @override
  List<String> get examplePhrases => [
        '我注意到X号和Y号的逻辑完全对不上，很可疑',
        'X号一直在保Y号，他们是不是有什么关系？',
        'X号说的和之前Y号说的矛盾了，谁在撒谎？',
        '大家有没有发现，X号一直在针对好人？',
        '我觉得X号和Y号可能不是一边的',
      ];

  @override
  bool isApplicable(GameState state, GamePlayer player) {
    // 适用于：
    // 1. 狼人挑拨离间（主要使用者）
    // 2. 游戏中后期更有效（第2天以后，有足够信息制造矛盾）
    if (player.role.id == 'werewolf' && state.day >= 2) {
      return true;
    }
    return false;
  }
}
