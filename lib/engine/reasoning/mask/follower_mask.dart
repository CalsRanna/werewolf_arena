import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 跟风者面具
///
/// 适用场景：狼人/平民混水、降低存在感
/// 特征：随大流、附和他人观点、降低威胁度
class FollowerMask extends RoleMask {
  @override
  String get id => 'follower';

  @override
  String get name => '跟风者';

  @override
  String get description => '随大流、附和他人观点、降低存在感';

  @override
  String get languageStyle => '''
发言特征：
- 附和他人："我同意X号的看法"
- 重复观点："就像X号说的那样"
- 跟随主流："我也觉得应该出X号"
- 不发表独立见解
- 语气随和、无威胁性
- 发言长度控制在30-50字（简短）
''';

  @override
  String get tone => '随和、附和、低调';

  @override
  List<String> get examplePhrases => [
    '我同意X号的分析，说得很有道理',
    '我也是这么想的，跟X号一样',
    '听起来X号的逻辑没问题，我支持',
    '我跟大家的想法一致',
    '我没有特别的想法，听大家的',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用于：
    // 1. 狼人混水（降低存在感，避免成为焦点）
    // 2. 平民（真的没有太多信息）
    // 3. 任何阶段都可使用
    if (player.role.id == 'werewolf' || player.role.id == 'villager') {
      return true;
    }
    return false;
  }
}
