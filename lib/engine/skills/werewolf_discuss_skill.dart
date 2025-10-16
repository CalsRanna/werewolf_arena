import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// 狼人讨论技能（夜晚专用）
///
/// 狼人之间的私密讨论，只有狼人可见
class WerewolfDiscussSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_discuss';

  @override
  String get name => '狼人讨论';

  @override
  String get description => '与狼人队友进行私密讨论';

  @override
  String get prompt => '''
# **狼人战术会议**

夜幕已深，我的同伴。这里是我们的专属频道，绝对安全。

白天的闹剧结束了，现在是我们梳理情报、制定下一步计划的时候。仔细回想一下：
- 白天那些跳身份的，谁是真神，谁在诈唬？
- 谁的发言让我们感到威胁最大，可能是那个讨厌的预言家或者女巫？
- 我们今晚的刀口，应该对准谁才能收益最大化？
- 明天白天，我们是集体冲锋一个好人，还是分头行动，甚至找个机会卖掉一个暴露的队友打倒钩？

我们必须统一思路。说出你的判断和计划，让我们拧成一股绳，撕开好人的防线。
''';
}
