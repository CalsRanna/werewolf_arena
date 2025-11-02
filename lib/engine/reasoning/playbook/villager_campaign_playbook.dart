import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 平民上警战术剧本
///
/// 核心思路：平民可以选择性上警，帮助神职拿警徽或混淆狼人视线，
/// 根据场上情况决定是否退水
class VillagerCampaignPlaybook extends Playbook {
  @override
  String get id => 'villager_campaign';

  @override
  String get name => '平民上警战术';

  @override
  String get description => '''
核心思路：平民上警有多种目的：1）混淆狼人视线，保护真神职；2）听完发言后帮真预言家拿警徽；
3）展示逻辑能力获得话语权。平民要灵活应变，该退水时要果断退水。
成功关键：不能抢神职的警徽，要在退水环节做出正确判断。
''';

  @override
  List<String> get applicableRoles => ['villager'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是平民
    // 2. 第1天
    // 3. 还没有警长
    if (player.role.id != 'villager') return false;
    if (state.day != 1) return false;
    if (state.sheriff != null) return false;

    return true;
  }

  @override
  String get coreGoal => '通过上警混淆视听或帮助好人阵营，根据场上情况灵活退水';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'campaign',
      action: '根据策略选择是否上警（可上可不上）',
      reasoning: '平民上警不是必须的，要根据局势判断',
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '如果上警，表明平民身份或展示逻辑分析能力',
      reasoning: '平民要坦诚，不要伪装身份，展现好人视角',
      exampleSpeech: [
        '我是一个平民，上警是想帮助好人阵营',
        '我上警不是为了拿警徽，而是想听听大家的发言',
        '我会用平民的视角帮大家分析局势',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '表达愿意为好人阵营服务的态度',
      reasoning: '平民要展现团队精神和奉献精神',
      exampleSpeech: [
        '如果有真预言家跳出来，我会退水让他拿警徽',
        '我愿意为好人阵营做贡献',
      ],
    ),
    PlaybookStep(
      phase: 'withdraw',
      action: '如果有预言家跳出来，果断退水',
      reasoning: '平民不能抢神职的警徽，这是基本素养',
    ),
    PlaybookStep(
      phase: 'withdraw',
      action: '如果只有狼人跳预言家，可以选择不退水，继续竞争警徽',
      reasoning: '不能让狼人轻易拿到警徽',
    ),
    PlaybookStep(
      phase: 'sheriff_vote',
      action: '投票给真预言家或最像好人的玩家',
      reasoning: '帮助真预言家拿到警徽',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我是平民，上警是为了帮助好人',
    '如果有预言家，我会退水',
    '我不会抢神职的警徽',
    '我会用逻辑分析帮大家找狼',
    '平民也有责任为好人阵营做贡献',
    '我愿意用我的发言位帮大家',
    '听完发言我会做出正确的选择',
  ];

  @override
  List<String> get risks => [
    '上警容易成为狼人刀口',
    '发言不好可能被怀疑',
    '抢了神职的警徽会被质疑',
    '退水时机不当会引起怀疑',
  ];

  @override
  String get successCriteria => '成功帮助真预言家拿到警徽，或通过退水展现好人立场';
}
