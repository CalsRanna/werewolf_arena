import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/state/game_state.dart';
import 'package:werewolf_arena/engine/events/player_events.dart';

/// 发言技能（白天专用）
///
/// 玩家在白天阶段的正常发言
class SpeakSkill extends GameSkill {
  @override
  String get skillId => 'speak';

  @override
  String get name => '发言';

  @override
  String get description => '在白天阶段进行发言讨论';

  @override
  int get priority => 50; // 普通优先级

  @override
  String get prompt => '''
现在是白天讨论阶段，请进行你的发言。

你可以选择以下发言策略：
1. 分享信息：公布你掌握的信息（如果你是神职）
2. 分析推理：分析昨晚的结果和玩家行为
3. 表达怀疑：指出你怀疑的玩家并说明理由
4. 为自己辩护：如果被怀疑，为自己澄清
5. 引导投票：建议大家投票给特定玩家

发言要点：
- 保持逻辑性和说服力
- 根据你的角色身份调整发言策略
- 观察其他玩家的反应
- 为接下来的投票做准备

请发表你的观点：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced && state.currentPhase.isDay;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成发言技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {'skillId': skillId, 'speechType': 'normal'},
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}

/// 信息公布技能（白天专用）
///
/// 神职玩家公布重要信息的专用技能
class InformationShareSkill extends GameSkill {
  @override
  String get skillId => 'share_information';

  @override
  String get name => '信息公布';

  @override
  String get description => '公布掌握的关键信息';

  @override
  int get priority => 60; // 较高优先级

  @override
  String get prompt => '''
作为神职玩家，你可以选择公布你掌握的关键信息。

信息公布策略：
1. 预言家：公布查验结果，指出狼人
2. 女巫：公布用药情况，澄清死亡原因
3. 守卫：必要时公布守护信息
4. 猎人：暗示身份，威慑狼人

公布时机：
- 确认狼人身份时
- 被怀疑需要澄清时
- 关键投票前
- 局势紧张时

注意风险：
- 公布身份会成为狼人目标
- 假神可能冒充你的身份
- 信息可能被狼人利用

请谨慎选择公布的信息：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        !player.isSilenced &&
        player.role.isGod &&
        state.currentPhase.isDay;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成信息公布技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'speechType': 'information_share',
          'roleType': player.role.roleId,
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}

/// 辩护技能（白天专用）
///
/// 被怀疑时的自我辩护
class DefenseSkill extends GameSkill {
  @override
  String get skillId => 'defense';

  @override
  String get name => '自我辩护';

  @override
  String get description => '为自己进行辩护澄清';

  @override
  int get priority => 70; // 高优先级

  @override
  String get prompt => '''
你被其他玩家怀疑了，现在是为自己辩护的时机。

辩护策略：
1. 逻辑反驳：指出对方指控的漏洞
2. 提供证据：展示支持你身份的证据
3. 反击质疑：质疑指控者的动机
4. 身份暗示：暗示你的真实身份（如果有利）
5. 转移目标：指出真正可疑的玩家

辩护要点：
- 保持冷静和逻辑性
- 不要过度激动（容易被认为心虚）
- 提供具体的事实和推理
- 争取其他玩家的支持

请为自己进行有力的辩护：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    // 检查是否被其他玩家怀疑或指控
    final recentSpeeches = state.eventHistory
        .whereType<SpeakEvent>()
        .where(
          (event) =>
              event.dayNumber == state.dayNumber &&
              event.speaker != player &&
              event.message.contains(player.name),
        )
        .toList();

    return player.isAlive &&
        !player.isSilenced &&
        state.currentPhase.isDay &&
        recentSpeeches.isNotEmpty;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成辩护技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {'skillId': skillId, 'speechType': 'defense'},
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}

/// 指控技能（白天专用）
///
/// 指控其他玩家是狼人
class AccusationSkill extends GameSkill {
  @override
  String get skillId => 'accusation';

  @override
  String get name => '指控';

  @override
  String get description => '指控其他玩家是狼人';

  @override
  int get priority => 65; // 较高优先级

  @override
  String get prompt => '''
你可以指控其他玩家是狼人。

指控策略：
1. 基于证据：用具体的事实支持你的指控
2. 行为分析：分析目标的可疑行为
3. 逻辑推理：通过推理得出结论
4. 投票引导：为投票阶段做准备

指控要点：
- 提供充分的理由和证据
- 分析目标的发言和行为模式
- 考虑目标的投票历史
- 争取其他玩家的认同

请选择你要指控的目标并说明理由：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced && state.currentPhase.isDay;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取可指控的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player)
          .toList();

      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to accuse',
          },
        );
      }

      // 生成指控技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'speechType': 'accusation',
          'availableTargets': availableTargets.length,
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}

/// 分析技能（白天专用）
///
/// 分析当前局势和玩家行为
class AnalysisSkill extends GameSkill {
  @override
  String get skillId => 'analysis';

  @override
  String get name => '局势分析';

  @override
  String get description => '分析当前游戏局势和玩家行为';

  @override
  int get priority => 55; // 中等优先级

  @override
  String get prompt => '''
你可以分析当前的游戏局势。

分析内容：
1. 阵营分析：好人和狼人的大致数量
2. 死亡分析：分析死亡玩家的身份和死因
3. 行为分析：分析玩家的发言和投票行为
4. 趋势分析：分析游戏发展趋势
5. 策略建议：提出下一步行动建议

分析角度：
- 从昨晚的结果推断
- 从投票模式分析
- 从发言内容判断
- 从时间节点考虑

请进行你的局势分析：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced && state.currentPhase.isDay;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 收集分析数据
      final deadPlayers = state.deadPlayers.length;
      final alivePlayers = state.alivePlayers.length;
      final dayNumber = state.dayNumber;

      // 生成分析技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'speechType': 'analysis',
          'deadCount': deadPlayers,
          'aliveCount': alivePlayers,
          'dayNumber': dayNumber,
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}

/// 投票引导技能（白天专用）
///
/// 引导其他玩家的投票选择
class VoteGuidanceSkill extends GameSkill {
  @override
  String get skillId => 'vote_guidance';

  @override
  String get name => '投票引导';

  @override
  String get description => '引导其他玩家的投票选择';

  @override
  int get priority => 75; // 高优先级

  @override
  String get prompt => '''
你可以引导其他玩家的投票选择。

引导策略：
1. 明确目标：清楚地指出应该投票的目标
2. 理由充分：提供投票该目标的充分理由
3. 危险警告：警告不投票的后果
4. 联合行动：呼吁其他玩家一起行动
5. 策略说明：解释投票策略的重要性

引导要点：
- 展现领导力和判断力
- 用逻辑说服其他玩家
- 营造紧迫感
- 建立信任和权威

请引导大家的投票方向：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced && state.currentPhase.isDay;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成投票引导技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {'skillId': skillId, 'speechType': 'vote_guidance'},
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}
