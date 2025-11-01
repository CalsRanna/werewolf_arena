import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/playbook/playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 狼人倒钩战术剧本
///
/// 核心思路：伪装成理性好人，站边真预言家，
/// 必要时投出狼队友，骗取好人最高信任
class WerewolfHookPlaybook extends Playbook {
  @override
  String get id => 'werewolf_hook';

  @override
  String get name => '狼人倒钩战术';

  @override
  String get description => '''
核心思路：伪装成理性好人，站边真预言家，必要时投出狼队友，骗取好人最高信任。
成功关键：要真的像好人一样思考，完全不为狼队友辩护，决赛圈再反水。
''';

  @override
  List<String> get applicableRoles => ['werewolf'];

  @override
  bool canActivate(GameState state, GamePlayer player) {
    // 触发条件：
    // 1. 自己是狼人
    // 2. 第2天以后（或有队友悍跳）
    // 3. 自己尚未暴露
    if (player.role.id != 'werewolf') return false;

    // 简化实现：第2天后都可以使用
    return state.day >= 2;
  }

  @override
  String get coreGoal => '深度潜伏，骗取好人信任，决赛圈关键时刻反水';

  @override
  List<PlaybookStep> get steps => [
        PlaybookStep(
          phase: 'day',
          action: '站边真预言家，表现出理性分析',
          reasoning: '好人会信任站边正确的人',
        ),
        PlaybookStep(
          phase: 'day',
          action: '适度攻击悍跳狼队友，但不要太激进',
          reasoning: '表现出"被说服"的过程，而不是立刻确定',
        ),
        PlaybookStep(
          phase: 'vote',
          action: '投票给暴露的狼队友',
          reasoning: '这是倒钩的核心：牺牲队友换取信任',
        ),
        PlaybookStep(
          phase: 'day',
          action: '后续几天保持低调，做逻辑分析，但不要太强势',
          reasoning: '避免成为焦点，继续伪装好人',
        ),
        PlaybookStep(
          phase: 'vote',
          action: '决赛圈（2-3人时）关键投票反水',
          reasoning: '最后时刻暴露身份，带走好人',
        ),
      ];

  @override
  List<String> get keyPhrases => [
        '我觉得X号（真预言家）说得有道理',
        '虽然Y号是我朋友，但我不能感情用事',
        '从逻辑上看，Y号确实可能是狼',
        '我是理性玩家，我只看逻辑',
        '今天我跟真预言家的票',
      ];

  @override
  List<String> get risks => [
        '可能被狼队友误认为是真好人，夜晚被刀',
        '如果表现太完美，可能被高端好人识破倒钩',
        '决赛圈反水时可能已经没有数量优势',
      ];

  @override
  String get successCriteria => '成功活到决赛圈并拥有决定性的一票';
}
