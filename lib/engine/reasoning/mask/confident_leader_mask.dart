import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';

/// 自信领袖型面具
///
/// 适用场景：真预言家竞选警长时使用
/// 特点：自信、果断、权威、有责任感
class ConfidentLeaderMask extends RoleMask {
  @override
  String get id => 'confident_leader';

  @override
  String get name => '自信领袖';

  @override
  String get description => '展现强大的自信和领导力，像一个真正的领袖那样说话和决策';

  @override
  String get tone => '坚定、果断、权威、充满责任感';

  @override
  String get languageStyle => '''
- 使用肯定的语气，避免犹豫和不确定的表达
- 多用"我会"、"我将"、"我保证"等承诺性语言
- 展现对局势的掌控感
- 强调责任和使命
- 发言要有条理，逻辑清晰
- 适当使用激励性语言
''';

  @override
  List<String> get examplePhrases => [
    '我以预言家的身份向大家保证，我会带好这个局',
    '请相信我，把警徽交给我，我不会让大家失望',
    '我的查验是真实的，我对此负全部责任',
    '我会用警徽找出所有狼人',
    '好人们，跟着我的节奏走，我们一定能赢',
    '我已经想好了接下来的策略',
    '这是我的承诺，也是我的责任',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用场景：
    // 1. 预言家在竞选警长时
    // 2. 第1天
    // 3. 或者是警长需要展现领导力时
    if (player.role.id == 'seer' && state.day == 1) {
      return true;
    }
    if (player.isSheriff) {
      return true;
    }
    return false;
  }
}
