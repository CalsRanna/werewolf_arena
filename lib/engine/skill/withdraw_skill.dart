import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 退水技能 - 上警玩家在竞选发言后退出竞选
class WithdrawSkill extends GameSkill {
  @override
  String get id => 'withdraw';

  @override
  String get name => '退水';

  @override
  String get description => '退出警长竞选';

  @override
  String get prompt => '''
现在是退水环节。你已经发表了竞选宣言，现在可以选择是否退水（退出竞选）。

退水的常见情况：
- 听到真预言家发言后，跳预言家的狼人可能退水
- 平民听到神职发言后，为了让神职拿警徽而退水
- 战术性退水以混淆场上局势

是否退水的考虑因素：
- 其他上警玩家的发言内容
- 你的真实身份和伪装身份
- 当前局势对你的有利程度
- 是否需要继续竞争警徽

请决定是否退水：
- 如果退水，请回复："退水"
- 如果不退水，请回复："不退水"

只需要回复上述两个选项之一即可。
''';
}
