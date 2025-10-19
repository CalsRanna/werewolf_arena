import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 遗言技能（被投票出局后发表遗言）
///
/// 玩家被投票出局后发表最后的遗言
class TestamentSkill extends GameSkill {
  @override
  String get skillId => 'testament';

  @override
  String get name => '遗言';

  @override
  String get description => '被投票出局后发表遗言';

  @override
  String get prompt => '''
你已经被投票出局了。现在你可以发表你的遗言。

遗言策略：
1. 如果你是好人：
   - 公布你掌握的关键信息
   - 指出你怀疑的狼人
   - 为好人阵营留下线索
   - 表明你的身份（如果有必要）

2. 如果你是狼人：
   - 尽量混淆视听
   - 误导好人的判断
   - 保护你的狼队友
   - 可以假装是好人身份

3. 如果你是神职：
   - 公布你的查验/守护/救治信息
   - 帮助好人阵营理清局势
   - 为后续的投票提供依据

这是你最后的发言机会，请充分利用：
''';
}
