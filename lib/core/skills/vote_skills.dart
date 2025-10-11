import 'package:werewolf_arena/core/skills/game_skill.dart';
import 'package:werewolf_arena/core/skills/skill_result.dart';
import 'package:werewolf_arena/core/state/game_state.dart';

/// 普通投票技能
/// 
/// 白天阶段的正常投票，投票出局一名玩家
class VoteSkill extends GameSkill {
  @override
  String get skillId => 'vote';
  
  @override
  String get name => '投票';
  
  @override
  String get description => '投票出局一名玩家';
  
  @override
  int get priority => 60; // 较高优先级
  
  @override
  String get prompt => '''
现在是投票阶段，请选择你要投票出局的玩家。

投票策略：
1. 基于证据投票：根据掌握的信息和推理
2. 跟随可信玩家：跟随你信任的玩家投票
3. 策略性投票：考虑投票结果对局势的影响
4. 保护重要玩家：避免投票给确认的好人
5. 消除威胁：投票给最可疑的玩家

投票考虑因素：
- 玩家的发言内容和逻辑
- 玩家的行为模式
- 昨晚的死亡情况
- 其他玩家的态度
- 当前阵营形势

请慎重选择你的投票目标：
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           !player.isSilenced && 
           state.currentPhase.isDay &&
           state.isVoting;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取可投票的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player && p.isAlive)
          .toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to vote',
          },
        );
      }
      
      // 生成投票技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'voteType': 'normal',
          'availableTargets': availableTargets.length,
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

/// PK投票技能
/// 
/// 当出现平票时，进入PK阶段的投票
class PkVoteSkill extends GameSkill {
  @override
  String get skillId => 'pk_vote';
  
  @override
  String get name => 'PK投票';
  
  @override
  String get description => '在PK阶段投票选择出局玩家';
  
  @override
  int get priority => 65; // 高优先级
  
  @override
  String get prompt => '''
现在是PK投票阶段，出现了平票情况。

PK规则：
- 只能在平票的玩家中选择
- 平票玩家已经进行了最后发言
- 你需要根据他们的PK发言做出最终选择

PK投票策略：
1. 仔细听取PK发言：分析谁的发言更可信
2. 回顾全天表现：考虑整天的行为表现
3. 逻辑一致性：检查发言是否前后一致
4. 身份可信度：判断谁的身份更可信
5. 直觉判断：有时直觉也很重要

请在平票玩家中选择你认为应该出局的：
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           !player.isSilenced && 
           state.currentPhase.isDay &&
           state.isVoting &&
           state.votingState.isPkPhase;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取PK候选人
      final pkCandidates = state.votingState.pkCandidates;
      
      if (pkCandidates.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No PK candidates available',
          },
        );
      }
      
      // 确保投票者不在PK候选人中
      final availableTargets = pkCandidates
          .where((p) => p != player)
          .toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'Voter is in PK candidates, cannot vote',
          },
        );
      }
      
      // 生成PK投票技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'voteType': 'pk',
          'pkCandidatesCount': pkCandidates.length,
          'availableTargets': availableTargets.length,
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

/// 投票确认技能
/// 
/// 确认自己的投票选择
class VoteConfirmSkill extends GameSkill {
  @override
  String get skillId => 'vote_confirm';
  
  @override
  String get name => '确认投票';
  
  @override
  String get description => '确认投票选择';
  
  @override
  int get priority => 70; // 高优先级
  
  @override
  String get prompt => '''
请确认你的投票选择。

确认前请再次考虑：
1. 你的投票目标是否正确
2. 投票理由是否充分
3. 投票结果对局势的影响
4. 是否有更好的选择

一旦确认投票，将无法更改。
请慎重确认你的最终选择。
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    // 检查玩家是否已经投票但未确认
    final playerVotes = state.votingState.getCurrentVotes()
        .where((vote) => vote.voter == player)
        .toList();
    
    return player.isAlive && 
           !player.isSilenced && 
           state.currentPhase.isDay &&
           state.isVoting &&
           playerVotes.isNotEmpty &&
           !state.votingState.isVoteConfirmed(player);
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 标记投票已确认
      state.votingState.confirmVote(player);
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'confirmed': true,
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

/// 投票更改技能
/// 
/// 在投票阶段更改投票目标
class VoteChangeSkill extends GameSkill {
  @override
  String get skillId => 'vote_change';
  
  @override
  String get name => '更改投票';
  
  @override
  String get description => '更改投票目标';
  
  @override
  int get priority => 65; // 较高优先级
  
  @override
  String get prompt => '''
你可以更改你的投票目标。

更改投票的原因可能包括：
1. 获得了新的信息
2. 其他玩家的发言改变了你的想法
3. 发现之前的判断有误
4. 投票形势发生变化
5. 需要策略性调整

请选择新的投票目标：
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    // 检查玩家是否已经投票且投票未确认
    final playerVotes = state.votingState.getCurrentVotes()
        .where((vote) => vote.voter == player)
        .toList();
    
    return player.isAlive && 
           !player.isSilenced && 
           state.currentPhase.isDay &&
           state.isVoting &&
           playerVotes.isNotEmpty &&
           !state.votingState.isVoteConfirmed(player) &&
           state.votingState.allowVoteChange;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 获取可投票的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player && p.isAlive)
          .toList();
      
      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to change vote to',
          },
        );
      }
      
      // 生成投票更改技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'voteType': 'changed',
          'availableTargets': availableTargets.length,
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

/// 弃票技能
/// 
/// 选择不投票给任何人
class AbstainVoteSkill extends GameSkill {
  @override
  String get skillId => 'abstain_vote';
  
  @override
  String get name => '弃票';
  
  @override
  String get description => '选择不投票给任何人';
  
  @override
  int get priority => 50; // 普通优先级
  
  @override
  String get prompt => '''
你可以选择弃票（不投票给任何人）。

弃票的情况：
1. 无法确定谁是狼人
2. 所有选择都有风险
3. 希望避免误投好人
4. 策略性考虑
5. 信息不足以做出判断

弃票的后果：
- 减少总投票数
- 可能导致平票
- 其他玩家可能质疑你的态度
- 影响投票结果

确定要弃票吗？
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           !player.isSilenced && 
           state.currentPhase.isDay &&
           state.isVoting &&
           state.votingState.allowAbstain;
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成弃票技能执行结果
      // 具体的事件创建由GameEngine处理
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'voteType': 'abstain',
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

/// PK发言技能
/// 
/// PK阶段的特殊发言技能
class PkSpeechSkill extends GameSkill {
  @override
  String get skillId => 'pk_speech';
  
  @override
  String get name => 'PK发言';
  
  @override
  String get description => '在PK阶段进行最后发言';
  
  @override
  int get priority => 80; // 高优先级
  
  @override
  String get prompt => '''
你进入了PK阶段，这是你最后的发言机会。

PK发言策略：
1. 强力辩护：为自己进行有力的辩护
2. 身份证明：提供支持你身份的证据
3. 指出真凶：指出真正的狼人
4. 情感诉求：争取其他玩家的同情和支持
5. 逻辑推理：用清晰的逻辑说服大家

PK发言要点：
- 这是最后机会，要全力以赴
- 保持冷静和逻辑性
- 提供新的信息或角度
- 争取关键玩家的支持
- 暴露对手的破绽

请进行你的PK发言：
''';
  
  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && 
           !player.isSilenced && 
           state.currentPhase.isDay &&
           state.votingState.isPkPhase &&
           state.votingState.pkCandidates.contains(player) &&
           !state.votingState.hasPlayerSpokenInPk(player);
  }
  
  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成PK发言技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理
      
      // 标记玩家已在PK阶段发言
      state.votingState.markPlayerSpokenInPk(player);
      
      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'speechType': 'pk_speech',
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