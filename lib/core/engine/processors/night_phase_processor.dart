import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'phase_processor.dart';
import 'action_processor.dart';

/// 夜晚阶段处理器
///
/// 负责处理游戏中的夜晚阶段，包括：
/// - 狼人行动（讨论和击杀）
/// - 守卫守护行动
/// - 预言家查验行动
/// - 女巫用药行动（解药和毒药）
/// - 夜晚行动结算
class NightPhaseProcessor implements PhaseProcessor {
  /// 行动处理器列表
  final List<ActionProcessor> actionProcessors;

  NightPhaseProcessor({required this.actionProcessors});

  @override
  GamePhase get supportedPhase => GamePhase.night;

  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理夜晚阶段 - 第${state.dayNumber}夜');

    // 清空夜晚行动数据
    state.nightActions.clearNightActions();

    // 使用行动处理器按顺序处理各角色行动
    for (final processor in actionProcessors) {
      try {
        await processor.process(state);
      } catch (e) {
        LoggerUtil.instance.e('行动处理器处理失败: $e');
        await _handleGameError(e);
      }
    }

    // 结算夜晚行动结果
    await _resolveNightActions(state);

    LoggerUtil.instance.d('夜晚阶段处理完成');
  }

  /// 结算夜晚行动结果
  Future<void> _resolveNightActions(GameState state) async {
    LoggerUtil.instance.d('开始结算夜晚行动结果');

    final Player? victim = state.nightActions.tonightVictim;
    final Player? protected = state.nightActions.tonightProtected;
    final Player? poisoned = state.nightActions.tonightPoisoned;

    // 处理击杀（如果被守护或救治则取消）
    if (victim != null && !state.nightActions.killCancelled && victim != protected) {
      victim.die(DeathCause.werewolfKill, state);
      LoggerUtil.instance.d('玩家 ${victim.name} 被狼人击杀');
    }

    // 处理毒杀（如果被守护则无效）
    if (poisoned != null && poisoned != protected) {
      poisoned.die(DeathCause.poison, state);
      LoggerUtil.instance.d('玩家 ${poisoned.name} 被毒杀');
    }

    // 清空夜晚行动数据
    state.nightActions.clearNightActions();

    LoggerUtil.instance.d('夜晚行动结果结算完成');
  }

  /// Handle game error - don't stop phase, log error and continue
  Future<void> _handleGameError(dynamic error) async {
    LoggerUtil.instance.e('Night phase error: $error');
    // Just log and continue with next processor
  }
}