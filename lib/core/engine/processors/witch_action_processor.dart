import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'package:werewolf_arena/core/events/system_events.dart';
import 'action_processor.dart';

/// 女巫行动处理器
///
/// 负责处理女巫在夜晚阶段的行动，包括：
/// - 解药决策和使用
/// - 毒药决策和使用
/// - 验证用药合法性
/// - 管理女巫的药水状态
class WitchActionProcessor implements ActionProcessor {
  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理女巫行动');

    final witches = state.alivePlayers
        .where((p) => p.role.runtimeType.toString().contains('Witch'))
        .cast<Player>()
        .toList();

    if (witches.isEmpty) {
      LoggerUtil.instance.d('没有存活的女巫，跳过女巫行动');
      return;
    }

    LoggerUtil.instance.d('处理女巫行动，存活女巫数量：${witches.length}');

    // 依次处理每个女巫的行动
    for (int i = 0; i < witches.length; i++) {
      final witch = witches[i];
      await _processWitchAction(
        witch as AIPlayer,
        state,
        i < witches.length - 1,
      );
    }

    LoggerUtil.instance.d('女巫行动处理完成');
  }

  /// 处理单个女巫的行动
  Future<void> _processWitchAction(
    AIPlayer witch,
    GameState state,
    bool hasMoreWitches,
  ) async {
    if (!witch.isAlive) {
      LoggerUtil.instance.w('尝试处理已死亡的女巫 ${witch.name} 的行动');
      return;
    }

    try {
      LoggerUtil.instance.d('处理女巫 ${witch.name} 的行动');

      // 更新玩家事件日志
      PlayerLogger.instance.updatePlayerEvents(witch, state);

      // 处理信息
      await witch.processInformation(state);

      // 第一步：处理解药决策
      await _processAntidoteDecision(witch, state);

      // 第二步：处理毒药决策
      await _processPoisonDecision(witch, state);
    } catch (e) {
      LoggerUtil.instance.e('处理女巫 ${witch.name} 行动失败: $e');
    }

    // 多个女巫间的行动延迟
    if (hasMoreWitches) {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  /// 处理女巫的解药决策
  Future<void> _processAntidoteDecision(AIPlayer witch, GameState state) async {
    // 检查女巫是否有解药
    if (!_hasAntidote(witch, state)) {
      LoggerUtil.instance.d('女巫 ${witch.name} 没有解药，跳过解药决策');
      return;
    }

    LoggerUtil.instance.d('处理女巫 ${witch.name} 的解药决策');

    // 显示今晚的死亡情况
    final victim = state.nightActions.tonightVictim;
    if (victim != null) {
      LoggerUtil.instance.d('今晚死亡玩家：${victim.name}');
    } else {
      LoggerUtil.instance.d('今晚是平安夜，没有人死亡');
    }

    // 询问女巫是否使用解药
    final shouldUseAntidote = await _askWitchAboutAntidote(witch, state);

    if (shouldUseAntidote && victim != null) {
      // 使用解药
      final event = witch.createHealEvent(victim, state);
      if (event != null) {
        witch.executeEvent(event, state);
        LoggerUtil.instance.d('女巫 ${witch.name} 使用解药救活 ${victim.name}');

        // 记录解药使用
        _recordAntidoteUsage(witch, state);
      } else {
        LoggerUtil.instance.debug('女巫 ${witch.name} 未能创建有效的救治事件');
      }
    } else {
      LoggerUtil.instance.d('女巫 ${witch.name} 选择不使用解药');
    }
  }

  /// 处理女巫的毒药决策
  Future<void> _processPoisonDecision(AIPlayer witch, GameState state) async {
    // 检查女巫是否有毒药
    if (!_hasPoison(witch, state)) {
      LoggerUtil.instance.d('女巫 ${witch.name} 没有毒药，跳过毒药决策');
      return;
    }

    LoggerUtil.instance.d('处理女巫 ${witch.name} 的毒药决策');

    // 询问女巫是否使用毒药以及目标
    final poisonTarget = await _askWitchAboutPoison(witch, state);

    if (poisonTarget != null) {
      // 验证毒药目标的合法性
      if (_isValidPoisonTarget(witch, poisonTarget, state)) {
        final event = witch.createPoisonEvent(poisonTarget, state);
        if (event != null) {
          witch.executeEvent(event, state);
          LoggerUtil.instance.d('女巫 ${witch.name} 使用毒药毒杀 ${poisonTarget.name}');

          // 记录毒药使用
          _recordPoisonUsage(witch, state);

          // 添加公告事件，通知所有玩家有人被毒（但不说明是谁毒的）
          final announcement = JudgeAnnouncementEvent(
            announcement: '${poisonTarget.formattedName}昨晚被毒杀',
            dayNumber: state.dayNumber,
            phase: state.currentPhase,
          );
          state.addEvent(announcement);
        } else {
          LoggerUtil.instance.debug('女巫 ${witch.name} 未能创建有效的毒杀事件');
        }
      } else {
        LoggerUtil.instance.debug(
          '女巫 ${witch.name} 选择的毒药目标 ${poisonTarget.name} 不合法',
        );
      }
    } else {
      LoggerUtil.instance.d('女巫 ${witch.name} 选择不使用毒药');
    }
  }

  /// 检查女巫是否有解药
  bool _hasAntidote(AIPlayer witch, GameState state) {
    // 这里需要根据女巫角色的实际实现来检查
    // 暂时使用简单的元数据检查
    final witchKey = 'witch_${witch.name}_has_antidote';
    return state.metadata[witchKey] ?? true; // 默认有解药
  }

  /// 检查女巫是否有毒药
  bool _hasPoison(AIPlayer witch, GameState state) {
    // 这里需要根据女巫角色的实际实现来检查
    // 暂时使用简单的元数据检查
    final witchKey = 'witch_${witch.name}_has_poison';
    return state.metadata[witchKey] ?? true; // 默认有毒药
  }

  /// 验证毒药目标的合法性
  bool _isValidPoisonTarget(AIPlayer witch, Player target, GameState state) {
    // 检查基本条件：目标必须存活
    if (!target.isAlive) {
      LoggerUtil.instance.w('女巫 ${witch.name} 尝试验杀已死亡的玩家 ${target.name}');
      return false;
    }

    // 检查是否毒杀自己（虽然允许，但需要特别提示）
    if (target.name == witch.name) {
      LoggerUtil.instance.w('女巫 ${witch.name} 尝试验杀自己');
      // 允许但记录警告
    }

    return true;
  }

  /// 询问女巫是否使用解药
  Future<bool> _askWitchAboutAntidote(AIPlayer witch, GameState state) async {
    try {
      final antidotePrompt = _buildAntidotePrompt(state);

      // 这里需要调用LLM服务获取决策
      // 由于现在在处理器中，我们需要通过某种方式获取LLM服务
      // 暂时返回false，待后续完善
      LoggerUtil.instance.d('询问女巫 ${witch.name} 解药决策: $antidotePrompt');

      // 简单的逻辑：如果有死亡且是第一夜，倾向于使用解药
      final victim = state.nightActions.tonightVictim;
      if (victim != null && state.dayNumber == 1) {
        return true;
      }

      return false;
    } catch (e) {
      LoggerUtil.instance.e('询问女巫 ${witch.name} 解药决策失败: $e');
      return false;
    }
  }

  /// 询问女巫是否使用毒药以及目标
  Future<Player?> _askWitchAboutPoison(AIPlayer witch, GameState state) async {
    try {
      final poisonPrompt = _buildPoisonPrompt(state);

      // 这里需要调用LLM服务获取决策
      // 暂时返回null，待后续完善
      LoggerUtil.instance.d('询问女巫 ${witch.name} 毒药决策: $poisonPrompt');

      return null;
    } catch (e) {
      LoggerUtil.instance.e('询问女巫 ${witch.name} 毒药决策失败: $e');
      return null;
    }
  }

  /// 构建解药决策提示
  String _buildAntidotePrompt(GameState state) {
    final victim = state.nightActions.tonightVictim;
    return '''
你是一个女巫。今晚${victim?.formattedName ?? '没有玩家'}死亡。

你现在需要决定是否使用你的解药：
- 如果使用解药，可以救活今晚死亡的玩家
- 解药只能使用一次，使用后就没有了
- 如果不使用，解药可以保留到后续夜晚

请简单回答：
- "使用解药" - 救活今晚死亡的玩家
- "不使用解药" - 保留解药到后续夜晚

${victim == null ? '今晚是平安夜，没有人死亡。' : ''}''';
  }

  /// 构建毒药决策提示
  String _buildPoisonPrompt(GameState state) {
    return '''
你是一个女巫。你有一瓶毒药可以毒杀一名玩家。

现在你需要决定是否使用毒药：
- 如果使用毒药，选择一名玩家进行毒杀
- 毒药只能使用一次，使用后就没有了
- 你可以毒杀任何存活的玩家（包括你自己，但不推荐）
- 考虑当前的游戏局势和谁是可疑的狼人

请回答：
1. 是否使用毒药（"使用毒药" 或 "不使用毒药"）
2. 如果选择使用，指定要毒杀的玩家编号

当前存活的玩家：
${state.players.where((p) => p.isAlive).map((p) => '- ${p.name}').join('\n')}''';
  }

  /// 记录解药使用
  void _recordAntidoteUsage(AIPlayer witch, GameState state) {
    final witchKey = 'witch_${witch.name}_has_antidote';
    state.metadata[witchKey] = false;

    final usageKey = 'witch_${witch.name}_antidote_used_day';
    state.metadata[usageKey] = state.dayNumber;

    LoggerUtil.instance.d('记录女巫 ${witch.name} 在第${state.dayNumber}天使用了解药');
  }

  /// 记录毒药使用
  void _recordPoisonUsage(AIPlayer witch, GameState state) {
    final witchKey = 'witch_${witch.name}_has_poison';
    state.metadata[witchKey] = false;

    final usageKey = 'witch_${witch.name}_poison_used_day';
    state.metadata[usageKey] = state.dayNumber;

    LoggerUtil.instance.d('记录女巫 ${witch.name} 在第${state.dayNumber}天使用了毒药');
  }

  /// 获取女巫的药水状态
  Map<String, dynamic> getWitchPotionStatus(AIPlayer witch, GameState state) {
    final antidoteKey = 'witch_${witch.name}_has_antidote';
    final poisonKey = 'witch_${witch.name}_has_poison';
    final antidoteUsedDayKey = 'witch_${witch.name}_antidote_used_day';
    final poisonUsedDayKey = 'witch_${witch.name}_poison_used_day';

    return {
      'hasAntidote': state.metadata[antidoteKey] ?? true,
      'hasPoison': state.metadata[poisonKey] ?? true,
      'antidoteUsedDay': state.metadata[antidoteUsedDayKey],
      'poisonUsedDay': state.metadata[poisonUsedDayKey],
    };
  }

  /// 获取可以毒杀的玩家列表
  List<Player> getValidPoisonTargets(AIPlayer witch, GameState state) {
    final validTargets = <Player>[];

    for (final player in state.alivePlayers) {
      if (_isValidPoisonTarget(witch, player, state)) {
        validTargets.add(player);
      }
    }

    LoggerUtil.instance.d(
      '女巫 ${witch.name} 的有效毒杀目标：${validTargets.map((p) => p.name).join('、')}',
    );
    return validTargets;
  }

  /// 分析女巫的药水使用策略
  String analyzeWitchStrategy(AIPlayer witch, GameState state) {
    final status = getWitchPotionStatus(witch, state);
    final currentDay = state.dayNumber;

    final analysis = <String>[];

    if (status['hasAntidote'] == true) {
      analysis.add('解药尚未使用');
    } else {
      final usedDay = status['antidoteUsedDay'];
      if (usedDay != null) {
        analysis.add('解药已在第${usedDay}天使用');
      }
    }

    if (status['hasPoison'] == true) {
      analysis.add('毒药尚未使用');
    } else {
      final usedDay = status['poisonUsedDay'];
      if (usedDay != null) {
        analysis.add('毒药已在第${usedDay}天使用');
      }
    }

    // 策略建议
    if (currentDay <= 3 && status['hasAntidote'] == true) {
      analysis.add('前期建议谨慎使用解药');
    }

    if (currentDay >= 5 && status['hasPoison'] == true) {
      analysis.add('后期可以考虑使用毒药清除可疑目标');
    }

    return analysis.join('；');
  }

  /// 清理女巫的药水记录（在游戏结束时调用）
  void clearWitchRecords(AIPlayer witch, GameState state) {
    final keysToRemove = [
      'witch_${witch.name}_has_antidote',
      'witch_${witch.name}_has_poison',
      'witch_${witch.name}_antidote_used_day',
      'witch_${witch.name}_poison_used_day',
    ];

    for (final key in keysToRemove) {
      state.metadata.remove(key);
    }

    LoggerUtil.instance.d('清理女巫 ${witch.name} 的药水使用记录');
  }
}
