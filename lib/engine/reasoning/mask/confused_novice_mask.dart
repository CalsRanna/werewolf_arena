import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 迷茫新手面具
///
/// 适用场景：狼人伪装平民、降低威胁度、避免成为焦点
/// 特征：展示理解不深、思考不清晰，但态度诚恳
class ConfusedNoviceMask extends RoleMask {
  @override
  String get id => 'confused_novice';

  @override
  String get name => '迷茫新手';

  @override
  String get description => '展示理解不深、思考不清晰，降低威胁度';

  @override
  String get languageStyle => '''
发言特征：
- 表达不确定："我不太确定..."，"可能是...吧？"
- 请教他人："大家怎么看？"，"有没有人能解释一下？"
- 承认困惑："我有点理不清思路"
- 简单跟随："我同意X号的分析"
- 语气谦虚、不自信
- 发言长度控制在30-60字（简短）
''';

  @override
  String get tone => '不确定、谦虚、迷茫';

  @override
  List<String> get examplePhrases => [
    '我不太懂这个逻辑，有点晕',
    '大家说得都有道理，我有点分不清',
    '我可能理解得不对，但我觉得可能是...',
    '有没有好人能帮我理一下思路？',
    '我先听听大家的想法，我不太确定',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用于：
    // 1. 狼人伪装平民时使用（降低威胁）
    // 2. 真正的平民也可以使用
    // 3. 游戏前期更适用（第1-2天）
    if (player.role.id == 'werewolf' || player.role.id == 'villager') {
      return state.day <= 2; // 前期更适合装新手
    }
    return false;
  }
}
