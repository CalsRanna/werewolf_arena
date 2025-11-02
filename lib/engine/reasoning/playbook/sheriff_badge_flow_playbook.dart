import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 警徽流传递策略剧本
///
/// 核心思路：当警长即将死亡时，通过警徽流传递关键信息，
/// 指引好人阵营的方向
class SheriffBadgeFlowPlaybook extends Playbook {
  @override
  String get id => 'sheriff_badge_flow';

  @override
  String get name => '警徽流传递策略';

  @override
  String get description => '''
核心思路：警长死亡时，警徽流的选择极其重要，它能传递关键信息。
预言家通常传给查验过的好人或按照预告的警徽流传递；
狼人警长可能传给狼队友或混淆视听；
平民警长传给最信任的人。
成功关键：警徽流的选择要符合逻辑，能够传递有价值的信息。
''';

  @override
  List<String> get applicableRoles => ['seer', 'werewolf', 'villager', 'witch', 'hunter', 'guard'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是警长
    // 2. 即将死亡（这个条件在实际使用时判断）
    if (!player.isSheriff) return false;

    return true;
  }

  @override
  String get coreGoal => '通过警徽流传递关键信息，指引好人阵营或混淆视听';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'testament',
      action: '【预言家】按照预告的警徽流传递，或传给查验过的好人',
      reasoning: '预言家的警徽流是重要信息，要忠于承诺或传递价值',
      exampleSpeech: [
        '我按照我的警徽流，把警徽传给X号',
        '我查验过X号是好人，警徽给他',
      ],
    ),
    PlaybookStep(
      phase: 'testament',
      action: '【狼人】可以传给狼队友建立身份，或传给好人混淆视听，或撕毁警徽',
      reasoning: '狼人的警徽流要为狼队创造优势',
      exampleSpeech: [
        '我把警徽传给X号，相信他能带好这个局',
        '我选择撕毁警徽，不让狼人利用',
      ],
    ),
    PlaybookStep(
      phase: 'testament',
      action: '【平民/神职】传给最信任的好人或预言家',
      reasoning: '让警徽发挥最大价值',
      exampleSpeech: [
        '我把警徽传给我最信任的X号',
        'X号应该是预言家，警徽给他',
      ],
    ),
    PlaybookStep(
      phase: 'testament',
      action: '如果局势混乱，不确定谁是好人，可以选择撕毁警徽',
      reasoning: '避免警徽落入狼人手中',
      exampleSpeech: [
        '我不确定谁是好人，选择撕毁警徽',
      ],
    ),
  ];

  @override
  List<String> get keyPhrases => [
    '我把警徽传给X号',
    '按照我的警徽流，传给...',
    '我查验过X号，警徽给他',
    '我最信任X号，警徽传给他',
    '我选择撕毁警徽',
    '不能让狼人拿到警徽',
    '警徽给最可能是好人的X号',
  ];

  @override
  List<String> get risks => [
    '传给狼人，帮助狼人获得优势',
    '违背警徽流承诺，被质疑身份',
    '撕毁警徽让好人失去优势',
  ];

  @override
  String get successCriteria => '警徽流传递给正确的人，或撕毁警徽避免狼人获利';
}
