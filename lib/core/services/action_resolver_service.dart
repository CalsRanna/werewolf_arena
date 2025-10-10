import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';

/// 行动解析服务
///
/// 负责解析和结算游戏中的夜晚行动，包括：
/// - 处理击杀、保护、治疗、毒杀的优先级
/// - 判断最终死亡结果
/// - 清理夜晚行动数据
class ActionResolverService {
  /// 解析夜晚行动结果
  ///
  /// [state] 游戏状态
  /// 返回最终死亡玩家列表
  List<Player> resolveNightActions(GameState state) {
    LoggerUtil.instance.d('开始结算夜晚行动结果');

    final Player? victim = state.nightActions.tonightVictim;
    final Player? protected = state.nightActions.tonightProtected;
    final Player? poisoned = state.nightActions.tonightPoisoned;

    final deadPlayers = <Player>[];

    // 处理击杀（如果被守护或救治则取消）
    if (victim != null && !state.nightActions.killCancelled && victim != protected) {
      victim.die(DeathCause.werewolfKill, state);
      deadPlayers.add(victim);
      LoggerUtil.instance.d('玩家 ${victim.name} 被狼人击杀');
    } else if (victim != null) {
      // 击杀被阻止的情况
      String? reason;
      if (state.nightActions.killCancelled) {
        reason = '被救治';
      } else if (victim == protected) {
        reason = '被守护';
      }
      LoggerUtil.instance.d('玩家 ${victim.name} 的击杀被${reason ?? '未知原因'}阻止');
    }

    // 处理毒杀（如果被守护则无效）
    if (poisoned != null && poisoned != protected) {
      poisoned.die(DeathCause.poison, state);
      deadPlayers.add(poisoned);
      LoggerUtil.instance.d('玩家 ${poisoned.name} 被毒杀');
    } else if (poisoned != null && poisoned == protected) {
      LoggerUtil.instance.d('玩家 ${poisoned.name} 的毒杀被守护阻止');
    }

    // 清空夜晚行动数据
    state.nightActions.clearNightActions();

    LoggerUtil.instance.d('夜晚行动结果结算完成，死亡玩家：${deadPlayers.map((p) => p.name).join('、')}');

    return deadPlayers;
  }

  /// 解析单一行动冲突
  ///
  /// [actionType] 行动类型
  /// [target] 目标玩家
  /// [state] 游戏状态
  /// 返回行动是否有效
  bool resolveActionConflict(
    String actionType,
    Player target,
    GameState state,
  ) {
    switch (actionType.toLowerCase()) {
      case 'kill':
        return _resolveKillAction(target, state);
      case 'poison':
        return _resolvePoisonAction(target, state);
      case 'protect':
        return _resolveProtectAction(target, state);
      case 'heal':
        return _resolveHealAction(target, state);
      default:
        return true; // 默认行动有效
    }
  }

  /// 解析击杀行动
  bool _resolveKillAction(Player target, GameState state) {
    // 检查是否被守护
    if (state.nightActions.tonightProtected == target) {
      LoggerUtil.instance.d('击杀行动被守护阻止：${target.name}');
      return false;
    }

    // 检查是否被救治
    if (state.nightActions.killCancelled) {
      LoggerUtil.instance.d('击杀行动被救治阻止：${target.name}');
      return false;
    }

    return true;
  }

  /// 解析毒杀行动
  bool _resolvePoisonAction(Player target, GameState state) {
    // 检查是否被守护
    if (state.nightActions.tonightProtected == target) {
      LoggerUtil.instance.d('毒杀行动被守护阻止：${target.name}');
      return false;
    }

    return true;
  }

  /// 解析守护行动
  bool _resolveProtectAction(Player target, GameState state) {
    // 守护行动总是有效，但可能有其他限制
    // 这里可以添加连续守护等特殊规则
    return true;
  }

  /// 解析救治行动
  bool _resolveHealAction(Player target, GameState state) {
    // 救治行动总是有效
    return true;
  }

  /// 获取行动优先级顺序
  ///
  /// 返回按优先级排序的行动类型列表
  List<String> getActionPriorityOrder() {
    return [
      'protect',    // 守护优先级最高
      'heal',       // 救治次之
      'poison',     // 毒杀再次
      'kill',       // 击杀最后结算
    ];
  }

  /// 验证行动组合的合法性
  ///
  /// [actions] 行动列表
  /// 返回组合是否合法
  bool validateActionCombination(List<Map<String, dynamic>> actions) {
    // 这里可以添加特殊的行动组合验证逻辑
    // 例如：同一玩家不能同时执行多个冲突的行动

    final Map<String, int> playerActionCount = {};

    for (final action in actions) {
      final player = action['player'] as Player?;
      if (player == null) continue;

      final playerName = player.name;
      playerActionCount[playerName] = (playerActionCount[playerName] ?? 0) + 1;
    }

    // 检查是否有玩家执行了多个行动
    for (final entry in playerActionCount.entries) {
      if (entry.value > 1) {
        LoggerUtil.instance.w('玩家 ${entry.key} 尝试执行多个行动：${entry.value}');
        return false;
      }
    }

    return true;
  }
}