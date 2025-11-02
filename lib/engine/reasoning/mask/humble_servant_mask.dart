import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';

/// 谦逊服务型面具
///
/// 适用场景：平民竞选警长时使用
/// 特点：谦虚、理性、愿意服务、不争不抢
class HumbleServantMask extends RoleMask {
  @override
  String get id => 'humble_servant';

  @override
  String get name => '谦逊服务者';

  @override
  String get description => '展现谦逊和服务精神，强调为团队贡献而非个人利益';

  @override
  String get tone => '谦虚、理性、服务导向、不争不抢';

  @override
  String get languageStyle => '''
- 使用谦虚的表达，避免过于强势
- 多用"我愿意"、"我希望"、"如果需要"等服务性语言
- 强调团队利益高于个人
- 表达对神职的尊重
- 展现理性和逻辑分析能力
- 随时准备让位给更合适的人
''';

  @override
  List<String> get examplePhrases => [
    '我只是一个平民，上警是想为好人阵营做点贡献',
    '如果有预言家需要警徽，我会毫不犹豫地退水',
    '我不会抢神职的位置，大家放心',
    '我愿意用我的逻辑帮大家分析局势',
    '警徽应该给最需要的人',
    '我的目标是帮助好人阵营，不是为了个人',
    '如果大家觉得我不合适，我随时可以退水',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用场景：
    // 1. 平民在竞选警长时
    // 2. 第1天
    if (player.role.id == 'villager' && state.day == 1) {
      return true;
    }
    return false;
  }
}
