import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 狼人抢警徽战术剧本
///
/// 核心思路：第一天上警跳预言家，争夺警徽，
/// 压制真预言家，掌控局面节奏
class WerewolfJumpSheriffPlaybook extends Playbook {
  @override
  String get id => 'werewolf_jump_sheriff';

  @override
  String get name => '狼人抢警徽战术';

  @override
  String get description => '''
核心思路：第一天上警跳预言家抢警徽，通过强势的发言和编造的查验结果压制真预言家。
成功关键：发言要比真预言家更有气势，查验结果要合理（通常给真预言家发查杀，或给狼队友发金水），
警徽流设计要合理。如果局势不利可以战术性退水。
抢到警徽后可以利用1.5票权重和警徽流误导好人。
''';

  @override
  List<String> get applicableRoles => ['werewolf'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是狼人
    // 2. 第1天
    // 3. 还没有警长（还没进行竞选）
    if (player.role.id != 'werewolf') return false;
    if (state.day != 1) return false;
    if (state.sheriff != null) return false;

    return true;
  }

  @override
  String get coreGoal => '跳预言家抢警徽，压制真预言家，掌控局面节奏';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'campaign',
      action: '果断选择上警',
      reasoning: '狼人抢警徽是常见战术，能获得话语权和投票优势',
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '强势宣布自己是预言家',
      reasoning: '气势要足，不能让真预言家压制',
      exampleSpeech: [
        '我是预言家，请大家相信我',
        '我拿了预言家牌，必须站出来',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '编造一个合理的查验结果：给可能是真预言家的人发查杀，或给狼队友发金水',
      reasoning: '查杀真预言家能直接对决；给队友发金水能建立狼人的好人身份',
      exampleSpeech: [
        '昨晚我验了X号，他是查杀，铁狼',
        '我第一晚验了X号，给了他金水',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '设计一个看起来合理的警徽流',
      reasoning: '警徽流要符合预言家的思路，增加可信度',
      exampleSpeech: [
        '我的警徽流是A顺验B',
        '如果拿到警徽，我会验...',
      ],
    ),
    PlaybookStep(
      phase: 'sheriff_speech',
      action: '展现强势和自信，攻击可能跳出来的真预言家',
      reasoning: '不能让真预言家站稳脚跟，要主动攻击',
      exampleSpeech: [
        '如果有人也跳预言家，那他一定是悍跳狼',
        '好人请站边我，我一定带你们赢',
      ],
    ),
    PlaybookStep(
      phase: 'withdraw',
      action: '根据局势判断是否退水：如果真预言家发言质量高且报出了强有力的信息，可以战术性退水',
      reasoning: '保存实力比硬刚更重要，退水可以混淆视听',
    ),
    PlaybookStep(
      phase: 'sheriff_vote',
      action: '如果没退水，号召狼队友和被蒙蔽的好人投票给自己',
      reasoning: '争取获得警徽，或至少让好人分裂站边',
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我是真预言家，请相信我',
    '昨晚我验了X号，他是查杀/金水',
    '我的警徽流是...',
    '如果有人跳预言家，那他一定是悍跳狼',
    '请把警徽给我，我会找出所有狼人',
    'X号（真预言家）的发言有明显破绽',
    '好人不要被骗了',
    '我以预言家的身份保证...',
  ];

  @override
  List<String> get risks => [
    '真预言家发言质量高，好人站边真预言家',
    '编造的查验结果与其他信息冲突（如女巫知道刀口）',
    '狼队友配合不到位，暴露破绽',
    '被识破后会成为集火目标',
    '退水时机不当，反而引起怀疑',
  ];

  @override
  String get successCriteria => '成功抢到警徽，或让好人阵营分裂站边，或通过退水混淆视听';
}
