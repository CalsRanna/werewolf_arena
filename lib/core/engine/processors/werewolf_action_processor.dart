import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/llm/enhanced_prompts.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'action_processor.dart';

/// 狼人行动处理器
///
/// 负责处理狼人在夜晚阶段的行动，包括：
/// - 狼人讨论阶段（多狼人时）
/// - 狼人投票选择击杀目标
/// - 单狼人直接决策
class WerewolfActionProcessor implements ActionProcessor {
  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理狼人行动');

    final werewolves = state.alivePlayers
        .where((p) => p.role.isWerewolf)
        .cast<Player>()
        .toList();

    if (werewolves.isEmpty) {
      LoggerUtil.instance.d('没有存活的狼人，跳过狼人行动');
      return;
    }

    LoggerUtil.instance.d('处理狼人行动，存活狼人数量：${werewolves.length}');

    if (werewolves.length == 1) {
      // 单个狼人独自决策
      await _processSingleWerewolf(werewolves.first as AIPlayer, state);
    } else {
      // 多个狼人需要讨论和投票
      await _processMultipleWerewolves(werewolves.cast<AIPlayer>(), state);
    }

    LoggerUtil.instance.d('狼人行动处理完成');
  }

  /// 处理单个狼人的行动
  Future<void> _processSingleWerewolf(
    AIPlayer werewolf,
    GameState state,
  ) async {
    if (!werewolf.isAlive) {
      LoggerUtil.instance.w('尝试处理已死亡的狼人 ${werewolf.name} 的行动');
      return;
    }

    try {
      LoggerUtil.instance.d('处理单个狼人 ${werewolf.name} 的行动');

      // 更新玩家事件日志
      PlayerLogger.instance.updatePlayerEvents(werewolf, state);

      // 处理信息
      await werewolf.processInformation(state);

      // 选择击杀目标
      final target = await werewolf.chooseNightTarget(state);

      if (target != null && target.isAlive) {
        final event = werewolf.createKillEvent(target, state);
        if (event != null) {
          werewolf.executeEvent(event, state);
          LoggerUtil.instance.d('狼人 ${werewolf.name} 选择击杀 ${target.name}');
        } else {
          LoggerUtil.instance.debug('狼人 ${werewolf.name} 未能创建有效的击杀事件');
        }
      } else {
        LoggerUtil.instance.debug('狼人 ${werewolf.name} 未选择有效目标');
      }
    } catch (e) {
      LoggerUtil.instance.e('处理单个狼人 ${werewolf.name} 行动失败: $e');
    }
  }

  /// 处理多个狼人的行动
  Future<void> _processMultipleWerewolves(
    List<AIPlayer> werewolves,
    GameState state,
  ) async {
    LoggerUtil.instance.d('处理多个狼人的行动，开始讨论阶段');

    // 第一阶段：狼人讨论
    await _processWerewolfDiscussion(werewolves, state);

    // 第二阶段：投票选择目标
    await _processWerewolfVoting(werewolves, state);
  }

  /// 处理狼人讨论阶段
  Future<void> _processWerewolfDiscussion(
    List<AIPlayer> werewolves,
    GameState state,
  ) async {
    LoggerUtil.instance.d('开始狼人讨论阶段');

    final discussionHistory = <String>[];

    for (int i = 0; i < werewolves.length; i++) {
      final werewolf = werewolves[i];

      if (!werewolf.isAlive) {
        LoggerUtil.instance.w('狼人 ${werewolf.name} 已死亡，跳过讨论');
        continue;
      }

      try {
        LoggerUtil.instance.d('处理狼人 ${werewolf.name} 的讨论');

        // 更新玩家事件日志
        PlayerLogger.instance.updatePlayerEvents(werewolf, state);

        // 处理信息
        await werewolf.processInformation(state);

        // 构建讨论上下文
        final context = _buildDiscussionContext(
          werewolf,
          state,
          discussionHistory,
        );

        // 生成讨论发言
        final statement = await werewolf.generateStatement(state, context);

        if (statement.isNotEmpty) {
          // 创建狼人讨论事件
          final event = werewolf.createWerewolfDiscussionEvent(
            statement,
            state,
          );
          if (event != null) {
            werewolf.executeEvent(event, state);

            // 添加到讨论历史
            discussionHistory.add('[${werewolf.name}]: $statement');

            LoggerUtil.instance.d('狼人 ${werewolf.name} 讨论发言: $statement');
          } else {
            LoggerUtil.instance.debug('狼人 ${werewolf.name} 无法创建讨论事件');
          }
        } else {
          LoggerUtil.instance.debug('狼人 ${werewolf.name} 未发言');
        }
      } catch (e) {
        LoggerUtil.instance.e('狼人 ${werewolf.name} 讨论失败: $e');
      }

      // 狼人间讨论延迟
      if (i < werewolves.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    LoggerUtil.instance.d('狼人讨论阶段结束，共${discussionHistory.length}位狼人发言');
  }

  /// 处理狼人投票阶段
  Future<void> _processWerewolfVoting(
    List<AIPlayer> werewolves,
    GameState state,
  ) async {
    LoggerUtil.instance.d('开始狼人投票阶段');

    final victims = <Player, int>{};
    final voteFutures = <Future<void>>[];

    // 收集所有狼人的投票任务（并发执行）
    for (final werewolf in werewolves) {
      if (werewolf.isAlive) {
        voteFutures.add(_processWerewolfVote(werewolf, state, victims));
      }
    }

    // 等待所有狼人同时完成投票
    await Future.wait(voteFutures);

    // 选择得票最多的目标
    if (victims.isNotEmpty) {
      final victim = victims.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      final firstWerewolf = werewolves.first;

      final event = firstWerewolf.createKillEvent(victim, state);
      if (event != null) {
        firstWerewolf.executeEvent(event, state);
        LoggerUtil.instance.d('狼人投票决定击杀 ${victim.name}（得票${victims[victim]}票）');

        // 记录投票统计
        victims.forEach((player, votes) {
          LoggerUtil.instance.d('  ${player.name}: ${votes}票');
        });
      }
    } else {
      LoggerUtil.instance.d('狼人未选择击杀目标');
    }

    LoggerUtil.instance.d('狼人投票阶段结束');
  }

  /// 处理单个狼人的投票
  Future<void> _processWerewolfVote(
    AIPlayer werewolf,
    GameState state,
    Map<Player, int> victims,
  ) async {
    try {
      LoggerUtil.instance.d('处理狼人 ${werewolf.name} 的投票');

      // 更新玩家事件日志
      PlayerLogger.instance.updatePlayerEvents(werewolf, state);

      // 处理信息（包含之前的讨论历史）
      await werewolf.processInformation(state);

      // 检查狼人是否能看到讨论历史
      final discussionEvents = state.eventHistory
          .whereType<WerewolfDiscussionEvent>()
          .where((e) => e.dayNumber == state.dayNumber)
          .toList();

      LoggerUtil.instance.d(
        '${werewolf.name} 可见的讨论事件数量: ${discussionEvents.length}',
      );
      if (discussionEvents.isNotEmpty) {
        LoggerUtil.instance.d('讨论内容预览: ${discussionEvents.first.message}');
      }

      // 选择击杀目标
      final target = await werewolf.chooseNightTarget(state);

      if (target != null && target.isAlive) {
        victims[target] = (victims[target] ?? 0) + 1;
        LoggerUtil.instance.d('狼人 ${werewolf.name} 投票给 ${target.name}');
      } else {
        LoggerUtil.instance.debug('狼人 ${werewolf.name} 未投票');
      }
    } catch (e) {
      LoggerUtil.instance.e('狼人 ${werewolf.name} 投票失败: $e');
    }
  }

  /// 构建狼人讨论上下文
  String _buildDiscussionContext(
    AIPlayer werewolf,
    GameState state,
    List<String> discussionHistory,
  ) {
    String context;

    if (state.dayNumber == 1) {
      // 第一夜使用增强的狼人讨论提示
      context = EnhancedPrompts.werewolfDiscussionPrompt;
    } else {
      // 后续夜晚基于白天讨论
      context = '狼人讨论阶段：请与其他狼人队友讨论今晚的策略，包括选择击杀目标、分析场上局势等。';
    }

    // 添加之前队友的发言
    if (discussionHistory.isNotEmpty) {
      context += '\n\n之前队友的发言：\n${discussionHistory.join('\n')}';
    }

    // 添加当前轮到该狼人发言的提示
    context += '\n\n现在轮到你发言，请分享你的想法和建议：';

    return context;
  }
}
