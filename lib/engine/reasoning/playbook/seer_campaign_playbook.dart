import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 预言家竞选警长战术剧本
///
/// 核心思路：第一天上警，通过报验人结果获取警徽，
/// 建立话语权和公信力，为后续指挥好人阵营打下基础
class SeerCampaignPlaybook extends Playbook {
  @override
  String get id => 'seer_campaign';

  @override
  String get name => '预言家竞选警长战术';

  @override
  String get description => '''
核心思路：第一天必须上警竞选，通过报第一晚的查验结果获取警徽。
成功关键：发言要自信坚定，查验结果要真实，警徽流设计要合理，展现预言家的权威和责任感。
警徽对预言家至关重要：1.5票权重能帮助推人，死后警徽流能传递关键信息。
''';

  @override
  List<String> get applicableRoles => ['seer'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是预言家
    // 2. 第1天
    // 3. 还没有警长（还没进行竞选）
    if (player.role.id != 'seer') return false;
    if (state.day != 1) return false;
    if (state.sheriff != null) return false;

    return true;
  }

  @override
  String get coreGoal => '上警竞选并获得警徽，建立话语权，为后续指挥好人阵营打下基础';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'campaign',
      action: '坚定选择上警',
      reasoning: '预言家必须拿警徽，警徽流和1.5票权重对预言家极其重要',
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '开门见山表明预言家身份',
      reasoning: '真预言家要有底气，不遮遮掩掩',
      exampleSpeech: [
        '我直接表明身份，我是预言家',
        '我拿了预言家这张牌',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '报出第一晚的查验结果（金水或查杀）',
      reasoning: '真实的查验结果是最有力的证据，建立公信力',
      exampleSpeech: [
        '昨晚我验了X号玩家，他是金水/查杀',
        '我第一晚的查验给到了X号',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '给出警徽流设计',
      reasoning: '警徽流既是验人计划，也是死后传递信息的方式',
      exampleSpeech: [
        '我的警徽流是A顺验B',
        '如果我拿到警徽，今晚会验X号，警徽流给到Y号',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '强调责任感和决心',
      reasoning: '展现预言家的领袖气质，获得好人信任',
      exampleSpeech: [
        '我会带好好人阵营，一定把狼人找出来',
        '请相信我，把警徽给我，我不会让大家失望',
      ],
    ),
    PlaybookStep(
      phase: 'withdraw',
      action: '坚决不退水',
      reasoning: '真预言家绝不退让，除非明确知道对方是真预言家',
    ),
    PlaybookStep(
      phase: 'sheriff_vote',
      action: '如果有狼人跳预言家抢警徽，在发言中揭露其破绽',
      reasoning: '与悍跳狼对抗，争取好人站边',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我是真预言家',
    '昨晚我验了X号，他是金水/查杀',
    '我的警徽流是...',
    '请把警徽给我，我会带好这个局',
    '如果我拿到警徽，今晚验...',
    '我发誓我是真预言家，请相信我',
    '狼人跳预言家是必然的，请仔细分辨',
    '我的查验结果是真实的，可以验证',
  ];

  @override
  List<String> get risks => [
    '狼人也跳预言家，可能编造更有说服力的查验',
    '如果报查杀，可能被查杀对象反扑',
    '警徽流设计不合理，会被质疑',
    '发言不够自信，被认为是假跳',
  ];

  @override
  String get successCriteria => '成功获得警徽，或至少让大多数好人相信自己是真预言家';
}
