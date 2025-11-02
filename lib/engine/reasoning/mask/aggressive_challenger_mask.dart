import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/mask/role_mask.dart';

/// 激进挑战型面具
///
/// 适用场景：狼人跳预言家抢警徽时使用
/// 特点：强势、攻击性、质疑对手、挑战权威
class AggressiveChallengerMask extends RoleMask {
  @override
  String get id => 'aggressive_challenger';

  @override
  String get name => '激进挑战者';

  @override
  String get description => '展现强势和攻击性，主动挑战对手，质疑其他人的逻辑';

  @override
  String get tone => '强势、犀利、攻击性、不留情面';

  @override
  String get languageStyle => '''
- 使用强势的表达，展现压迫感
- 多用质疑和反问句式
- 主动攻击对手的逻辑漏洞
- 强调自己的正确性
- 不给对手喘息空间
- 用气势压制对方
- 适当使用排比和强调句式
''';

  @override
  List<String> get examplePhrases => [
    '我就是真预言家，有人敢跳我就直接标狼',
    'X号的发言漏洞百出，明显是悍跳',
    '好人睁大眼睛看清楚，谁才是真的',
    '我不相信X号的查验，他根本就是编的',
    '今天必须出X号，不然好人就输了',
    '你们难道看不出来X号在说谎吗？',
    '我的逻辑没有任何问题，是X号在混淆视听',
  ];

  @override
  bool isApplicable(GameContext state, GamePlayer player) {
    // 适用场景：
    // 1. 狼人在竞选警长时（跳预言家）
    // 2. 第1-2天
    // 3. 需要强势压制真预言家时
    if (player.role.id == 'werewolf' && state.day <= 2) {
      return true;
    }
    return false;
  }
}
