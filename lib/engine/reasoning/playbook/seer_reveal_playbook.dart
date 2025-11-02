import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 预言家起跳剧本
///
/// 核心思路：在合适的时机公开自己的身份，
/// 用查验结果和逻辑说服好人相信自己
class SeerRevealPlaybook extends Playbook {
  @override
  String get id => 'seer_reveal';

  @override
  String get name => '预言家起跳战术';

  @override
  String get description => '''
核心思路：在合适的时机公开自己的身份，用查验结果和逻辑说服好人相信自己。
成功关键：起跳时机要好（第2天最佳），查验结果要清晰，逻辑要严密。
''';

  @override
  List<String> get applicableRoles => ['seer'];

  @override
  bool canActivate(GameContext state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是预言家
    // 2. 第1-3天
    // 3. 还没有起跳过（未来优化：需要在WorkingMemory中追踪起跳状态）
    if (player.role.id != 'seer') return false;
    if (state.day > 3) return false;

    return true;
  }

  @override
  String get coreGoal => '成功起跳并获得好人信任，带领好人阵营找出狼人';

  @override
  List<PlaybookStep> get steps => [
    PlaybookStep(
      phase: 'day',
      action: '选择合适的时机宣布自己是预言家',
      reasoning: '第2天起跳最佳：有查验结果，又不会太晚',
    ),
    PlaybookStep(
      phase: 'day',
      action: '公布所有查验结果，包括金水和查杀',
      reasoning: '完整的信息能增加可信度',
    ),
    PlaybookStep(phase: 'day', action: '给出警徽流和验人计划', reasoning: '展示长期规划，像真预言家'),
    PlaybookStep(
      phase: 'day',
      action: '如果有狼人悍跳，立刻指出对方的逻辑漏洞',
      reasoning: '主动攻击，不能被动防守',
    ),
    PlaybookStep(phase: 'vote', action: '带队投票给查杀的狼人', reasoning: '推出狼人是最好的证明'),
  ];

  @override
  List<String> get keyPhrases => [
    '我是预言家，必须跳出来了',
    '昨晚我验了X号，他是狼人/好人',
    '我的警徽流是...',
    '如果我被刀，请好人相信我的查验',
    '我不会骗大家，我的查验都是真的',
  ];

  @override
  List<String> get risks => [
    '狼人悍跳可能比自己先跳，抢占先机',
    '查验结果可能被狼人质疑',
    '起跳后容易成为狼人夜晚刀的目标',
  ];

  @override
  String get successCriteria => '好人相信自己是真预言家，成功推出至少一个狼人';
}
