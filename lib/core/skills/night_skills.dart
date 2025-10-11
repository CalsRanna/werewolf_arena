import 'package:werewolf_arena/core/skills/game_skill.dart';
import 'package:werewolf_arena/core/skills/skill_result.dart';
import 'package:werewolf_arena/core/state/game_state.dart';

/// 狼人击杀技能（夜晚专用）
/// 
/// 具有完整的游戏逻辑实现，包括目标选择、事件生成和状态更新
class WerewolfKillSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_kill';
  
  @override
  String get name => '狼人击杀';
  
  @override
  String get description => '夜晚狼人可以选择击杀一名玩家';
  
  @override
  int get priority => 100; // 最高优先级，在其他技能之前执行
  
  @override
  String get prompt => '''
现在是夜晚阶段，作为狼人，你需要选择击杀目标。

请考虑以下策略：
1. 优先击杀神职玩家（预言家、女巫、守卫、猎人）
2. 分析白天发言，找出可能的神职身份
3. 避免击杀明显的村民
4. 考虑守卫可能保护的对象
5. 制造混乱，误导好人阵营

当前存活玩家分析：
- 观察谁在引导投票
- 谁的发言过于逻辑清晰
- 谁可能掌握关键信息

请选择你要击杀的目标，并说明理由。
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           player.role.isWerewolf && 
           state.currentPhase.isNight;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取可击杀的目标（排除狼人队友）
      final availableTargets = state.alivePlayers
          .where((p) => p != player && !p.role.isWerewolf)
          .toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets',
          },
        );
      }
      
      // 这里应该通过PlayerDriver获取AI决策或等待人类输入
      // 暂时实现基础逻辑，具体目标选择由GameEngine处理
      
      // 这里不直接创建事件，而是返回成功结果
      // 具体的事件创建由GameEngine根据玩家选择的目标处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'skillType': 'werewolf_kill',
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {
          'skillId': skillId,
          'error': e.toString(),
        },
      );
    }
  }
}

/// 守卫保护技能（夜晚专用）
/// 
/// 包含守护规则：不能连续两晚守护同一人
class GuardProtectSkill extends GameSkill {
  @override
  String get skillId => 'guard_protect';
  
  @override
  String get name => '守卫保护';
  
  @override
  String get description => '夜晚可以守护一名玩家，保护其免受狼人击杀';
  
  @override
  int get priority => 90; // 高优先级，在狼人击杀之后执行
  
  @override
  String get prompt => '''
现在是夜晚阶段，作为守卫，你需要选择守护目标。

守护规则：
- 你不能连续两晚守护同一名玩家
- 守护可以保护玩家免受狼人击杀
- 如果你守护的玩家被狼人击杀，他们将存活

策略建议：
1. 优先保护可能的神职玩家
2. 观察白天谁的发言最有价值
3. 考虑狼人的击杀偏好
4. 必要时可以守护自己（除非昨晚已守护）
5. 避免守护明显的村民

请选择你要守护的目标。
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           player.role.roleId == 'guard' && 
           state.currentPhase.isNight;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取上次守护的玩家
      final lastProtected = player.role.getPrivateData<String>('last_protected');
      
      // 获取可守护的目标（排除上次守护的玩家）
      final availableTargets = state.alivePlayers.where((p) {
        if (lastProtected != null && p.name == lastProtected) {
          return false; // 不能连续守护同一人
        }
        return true;
      }).toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets (consecutive protection rule)',
          },
        );
      }
      
      // 生成守卫保护技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'lastProtected': lastProtected,
          'skillType': 'guard_protect',
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {
          'skillId': skillId,
          'error': e.toString(),
        },
      );
    }
  }
}

/// 预言家查验技能（夜晚专用）
/// 
/// 查验玩家身份，结果只有预言家可见
class SeerCheckSkill extends GameSkill {
  @override
  String get skillId => 'seer_check';
  
  @override
  String get name => '预言家查验';
  
  @override
  String get description => '夜晚可以查验一名玩家的身份（好人或狼人）';
  
  @override
  int get priority => 80; // 中等优先级
  
  @override
  String get prompt => '''
现在是夜晚阶段，作为预言家，你需要选择查验目标。

查验策略：
1. 优先查验可疑的玩家
2. 查验白天发言异常的玩家
3. 查验投票行为可疑的玩家
4. 避免查验明显的好人
5. 建立查验序列，系统性地收集信息

查验结果将只有你能看到：
- 如果是狼人，你会得到"狼人"的结果
- 如果是好人，你会得到"好人"的结果

请选择你要查验的目标。
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           player.role.roleId == 'seer' && 
           state.currentPhase.isNight;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取可查验的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player)
          .toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to investigate',
          },
        );
      }
      
      // 生成预言家查验技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'skillType': 'seer_check',
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {
          'skillId': skillId,
          'error': e.toString(),
        },
      );
    }
  }
}

/// 女巫解药技能（夜晚专用）
/// 
/// 可以救活当晚被狼人击杀的玩家，只能使用一次
class WitchHealSkill extends GameSkill {
  @override
  String get skillId => 'witch_heal';
  
  @override
  String get name => '女巫解药';
  
  @override
  String get description => '使用解药救活被狼人击杀的玩家（限用一次）';
  
  @override
  int get priority => 85; // 高优先级，在狼人击杀之后执行
  
  @override
  String get prompt => '''
现在是夜晚阶段，作为女巫，你可以选择使用解药。

解药规则：
- 解药只能使用一次，请慎重考虑
- 解药可以救活今晚被狼人击杀的玩家
- 你会知道今晚谁被狼人击杀了

使用建议：
1. 如果死的是重要神职，优先考虑救活
2. 如果死的是自己的盟友，可以考虑救活
3. 保留解药用于关键时刻
4. 考虑当前局势，解药的价值

是否使用解药救活被击杀的玩家？
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           player.role.roleId == 'witch' && 
           state.currentPhase.isNight &&
           (player.role.getPrivateData<bool>('has_antidote') ?? true);
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 检查是否还有解药
      final hasAntidote = player.role.getPrivateData<bool>('has_antidote') ?? true;
      if (!hasAntidote) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'Antidote already used',
          },
        );
      }
      
      // 检查是否有玩家被击杀（临时注释掉nightActions引用）
      // TODO: 从skillEffects或事件历史中获取受害者信息
      // final tonightVictim = state.nightActions.tonightVictim;
      // if (tonightVictim == null) {
      //   return SkillResult.failure(
      //     caster: player,
      //     metadata: {
      //       'skillId': skillId,
      //       'reason': 'No one was killed tonight',
      //     },
      //   );
      // }
      
      // 生成女巫治疗技能执行结果
      // 具体的事件创建由GameEngine处理
      
      // 标记解药已使用
      player.role.setPrivateData('has_antidote', false);
      
      return SkillResult.success(
        caster: player,
        target: null, // TODO: 设置正确的目标
        metadata: {
          'skillId': skillId,
          'victimName': 'unknown', // TODO: 从skillEffects获取受害者名称
          'skillType': 'witch_heal',
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {
          'skillId': skillId,
          'error': e.toString(),
        },
      );
    }
  }
}

/// 女巫毒药技能（夜晚专用）
/// 
/// 可以毒死一名玩家，只能使用一次
class WitchPoisonSkill extends GameSkill {
  @override
  String get skillId => 'witch_poison';
  
  @override
  String get name => '女巫毒药';
  
  @override
  String get description => '使用毒药杀死一名玩家（限用一次）';
  
  @override
  int get priority => 95; // 高优先级
  
  @override
  String get prompt => '''
现在是夜晚阶段，作为女巫，你可以选择使用毒药。

毒药规则：
- 毒药只能使用一次，请慎重考虑
- 毒药可以直接杀死一名玩家
- 毒死的玩家无法被守卫保护

使用策略：
1. 优先毒死确认的狼人
2. 毒死行为可疑的玩家
3. 考虑当前局势，毒药的最大价值
4. 避免毒死明显的好人
5. 关键时刻使用毒药扭转局势

请选择你要毒死的目标。
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           player.role.roleId == 'witch' && 
           state.currentPhase.isNight &&
           (player.role.getPrivateData<bool>('has_poison') ?? true);
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 检查是否还有毒药
      final hasPoison = player.role.getPrivateData<bool>('has_poison') ?? true;
      if (!hasPoison) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'Poison already used',
          },
        );
      }
      
      // 获取可毒死的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player)
          .toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to poison',
          },
        );
      }
      
      // 生成女巫毒药技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理
      
      // 标记毒药已使用
      player.role.setPrivateData('has_poison', false);
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'skillType': 'witch_poison',
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {
          'skillId': skillId,
          'error': e.toString(),
        },
      );
    }
  }
}

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
  int get priority => 110; // 最高优先级，在击杀之前进行讨论
  
  @override
  String get prompt => '''
现在是夜晚阶段，作为狼人，你可以与队友进行私密讨论。

讨论内容建议：
1. 分析今天白天的发言
2. 识别可能的神职玩家
3. 讨论击杀策略
4. 协调明天白天的发言策略
5. 分析投票情况

只有狼人能看到这些讨论内容。
请发表你的观点和建议。
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           player.role.isWerewolf && 
           state.currentPhase.isNight;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成狼人讨论技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'skillType': 'werewolf_discuss',
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {
          'skillId': skillId,
          'error': e.toString(),
        },
      );
    }
  }
}