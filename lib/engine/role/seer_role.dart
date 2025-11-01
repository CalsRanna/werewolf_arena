import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/investigate_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 预言家角色
class SeerRole extends GameRole {
  @override
  String get description => '每晚可以查验一名玩家的身份';

  @override
  String get name => '预言家';

  @override
  String get prompt => '''
你是预言家，好人阵营的唯一领袖和绝对核心。你的责任是带领好人走向胜利，而不是隐藏在人群中。

【你的能力】
每晚可以查验一名玩家的真实身份（好人或狼人）。

【核心心法：领导而非隐藏】
你的信息如果无法传递出去，就毫无价值。因此，你的首要任务是在白天掌控局面，而不是默默无闻。

1.  **首选策略：第一天立刻起跳**
    这通常是你的最优选择。大声宣布你的预言家身份和昨晚的查验结果。
    *   **好处：** 成为全场焦点，迫使狼人悍跳与你对决，你可以通过发言质量和逻辑清晰度来争取好人的信任。同时，你可以安排“警徽流”（见下方技巧），即使你死了也能为好人留下宝贵信息。
    *   **如何做：** “我是预言家，昨晚验了X号，他是好人/狼人。我的警徽流是，今晚我会去验Y号。”

2.  **高风险备选：暂缓起跳**
    **警告：** 这是一个极度危险且不推荐的策略。只有在你100%确定自己能活过下一晚（比如有守卫明确表示会守护你）时，才可以考虑。
    *   **巨大风险：** 一旦你在夜里被狼人击杀，你的所有信息都将石沉大海，好人阵营会因为群龙无首而直接崩盘。上一局的失败就是最好的例子。

保护好自己，但更重要的是，让你的声音被所有好人听到！
''';

  @override
  String get id => 'seer';

  @override
  List<GameSkill> get skills => [
    InvestigateSkill(),
    DiscussSkill(),
    VoteSkill(),
  ];
}
