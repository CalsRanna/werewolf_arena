import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/skills/game_skill.dart';
import 'package:werewolf_arena/core/skills/skill_result.dart';
import 'package:werewolf_arena/core/events/phase_events.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/engine/utils/game_random.dart';
import 'package:werewolf_arena/core/logging/game_engine_logger.dart';
import 'package:werewolf_arena/core/logging/game_log_event.dart';
import 'phase_processor.dart';

/// 白天阶段处理器（基于技能系统重构，包含发言和投票）
///
/// 负责处理游戏中的白天阶段，包括：
/// - 公布夜晚结果
/// - 玩家讨论发言（通过技能系统）
/// - 投票出局（合并原投票阶段）
class DayPhaseProcessor implements PhaseProcessor {
  final GameRandom _random = GameRandom();

  @override
  GamePhase get supportedPhase => GamePhase.day;

  @override
  Future<void> process(GameState state) async {
    GameEngineLogger.instance.info(
      GameLogCategory.phase,
      '开始处理白天阶段 - 第${state.dayNumber}天',
      metadata: {'dayNumber': state.dayNumber},
    );

    // 1. 阶段开始事件（所有人可见）
    state.addEvent(
      PhaseChangeEvent(
        oldPhase: state.currentPhase,
        newPhase: GamePhase.day,
        dayNumber: state.dayNumber,
      ),
    );

    // 2. 公布夜晚结果
    await _announceNightResults(state);

    // 3. 玩家讨论阶段（通过技能系统）
    await _runDiscussionPhase(state);

    // 4. 投票阶段（合并到白天阶段）
    await _runVotingPhase(state);

    // 5. 阶段结束事件（所有人可见）
    state.addEvent(
      PhaseChangeEvent(
        oldPhase: GamePhase.day,
        newPhase: GamePhase.night,
        dayNumber: state.dayNumber + 1,
      ),
    );

    // 6. 切换到夜晚阶段（开始新的一天）
    state.dayNumber++;
    await state.changePhase(GamePhase.night);

    GameEngineLogger.instance.info(GameLogCategory.phase, '白天阶段处理完成，准备进入下一个夜晚');
  }

  /// 公布夜晚结果
  Future<void> _announceNightResults(GameState state) async {
    GameEngineLogger.instance.debug(GameLogCategory.phase, '公布夜晚结果');

    // 筛选出今晚的死亡事件
    final deathEvents = state.eventHistory.whereType<DeadEvent>().toList();

    final isPeacefulNight = deathEvents.isEmpty;

    // 创建夜晚结果事件
    final nightResultEvent = NightResultEvent(
      deathEvents: deathEvents,
      isPeacefulNight: isPeacefulNight,
      dayNumber: state.dayNumber,
    );
    state.addEvent(nightResultEvent);

    // 记录夜晚结果
    if (isPeacefulNight) {
      GameEngineLogger.instance.info(
        GameLogCategory.phase,
        '第${state.dayNumber}夜是平安夜，无人死亡',
        metadata: {'dayNumber': state.dayNumber, 'nightResult': 'peaceful'},
      );
    } else {
      final deadPlayers = deathEvents.map((e) => e.victim.name).join('、');
      GameEngineLogger.instance.info(
        GameLogCategory.phase,
        '第${state.dayNumber}夜死亡玩家：$deadPlayers',
        metadata: {'dayNumber': state.dayNumber, 'deaths': deadPlayers},
      );
    }

    // 公布当前存活玩家
    final alivePlayers = state.alivePlayers;
    GameEngineLogger.instance.info(
      GameLogCategory.phase,
      '当前存活玩家：${alivePlayers.map((p) => p.name).join('、')}',
      metadata: {'aliveCount': alivePlayers.length},
    );
  }

  /// 运行讨论阶段 - 通过技能系统处理玩家发言
  Future<void> _runDiscussionPhase(GameState state) async {
    GameEngineLogger.instance.info(GameLogCategory.phase, '开始讨论阶段');

    // 获取发言顺序
    final speakingOrder = _getSpeakingOrder(state);

    // 收集当前阶段可用的发言技能
    final speakSkills = <GameSkill>[];
    for (final player in speakingOrder) {
      final playerSpeakSkills = player.role
          .getAvailableSkills(GamePhase.day)
          .where(
            (skill) =>
                skill.skillId.contains('speak') ||
                skill.skillId.contains('discussion'),
          );
      for (final skill in playerSpeakSkills) {
        if (skill.canCast(player, state)) {
          speakSkills.add(skill);
        }
      }
    }

    // 按发言顺序执行技能
    final speakResults = <SkillResult>[];
    for (final player in speakingOrder) {
      final playerSkills = speakSkills
          .where((skill) => player.role.skills.contains(skill))
          .toList();

      for (final skill in playerSkills) {
        try {
          GameEngineLogger.instance.debug(
            GameLogCategory.player,
            '处理玩家 ${player.name} 的发言',
            metadata: {'player': player.name},
          );

          final result = await player.executeSkill(skill, state);
          speakResults.add(result);

          if (result.success) {
            GameEngineLogger.instance.debug(
              GameLogCategory.player,
              '玩家 ${player.name} 发言完成',
              metadata: {'player': player.name},
            );
          }
        } catch (e) {
          GameEngineLogger.instance.error(
            GameLogCategory.player,
            '玩家 ${player.name} 发言失败: $e',
            metadata: {'player': player.name, 'error': e},
          );
        }

        // 玩家间发言延迟
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    GameEngineLogger.instance.info(
      GameLogCategory.phase,
      '讨论阶段结束，共${speakResults.length}位玩家发言',
      metadata: {'speakCount': speakResults.length},
    );
  }

  /// 运行投票阶段 - 通过技能系统处理投票
  Future<void> _runVotingPhase(GameState state) async {
    GameEngineLogger.instance.info(GameLogCategory.phase, '开始投票阶段');

    // 收集投票技能
    final voteSkills = <GameSkill>[];
    for (final player in state.alivePlayers) {
      final playerVoteSkills = player.role
          .getAvailableSkills(GamePhase.day)
          .where((skill) => skill.skillId.contains('vote'));
      for (final skill in playerVoteSkills) {
        if (skill.canCast(player, state)) {
          voteSkills.add(skill);
        }
      }
    }

    // 执行投票技能
    final voteResults = <SkillResult>[];
    for (final skill in voteSkills) {
      final player = state.alivePlayers.firstWhere(
        (p) => p.role.skills.contains(skill),
        orElse: () => throw Exception('未找到技能 ${skill.skillId} 的拥有者'),
      );

      try {
        GameEngineLogger.instance.debug(
          GameLogCategory.player,
          '处理玩家 ${player.name} 的投票',
          metadata: {'player': player.name},
        );

        final result = await player.executeSkill(skill, state);
        voteResults.add(result);

        if (result.success && result.target != null) {
          GameEngineLogger.instance.debug(
            GameLogCategory.player,
            '玩家 ${player.name} 投票给 ${result.target!.name}',
            metadata: {'voter': player.name, 'target': result.target!.name},
          );
        }
      } catch (e) {
        GameEngineLogger.instance.error(
          GameLogCategory.player,
          '玩家 ${player.name} 投票失败: $e',
          metadata: {'player': player.name, 'error': e},
        );
      }
    }

    // 处理投票结果
    await _processVotingResults(state, voteResults);

    GameEngineLogger.instance.info(GameLogCategory.phase, '投票阶段结束');
  }

  /// 处理投票结果
  Future<void> _processVotingResults(
    GameState state,
    List<SkillResult> voteResults,
  ) async {
    // 统计投票
    final Map<GamePlayer, int> voteCount = {};
    final Map<GamePlayer, List<GamePlayer>> voteDetails = {};

    for (final result in voteResults) {
      if (result.success && result.target != null) {
        final target = result.target!;
        voteCount[target] = (voteCount[target] ?? 0) + 1;
        voteDetails.putIfAbsent(target, () => []).add(result.caster);
      }
    }

    if (voteCount.isEmpty) {
      GameEngineLogger.instance.warning(GameLogCategory.phase, '没有有效投票，跳过出局');
      return;
    }

    // 找出得票最多的玩家
    final maxVotes = voteCount.values.reduce((a, b) => a > b ? a : b);
    final candidates = voteCount.entries
        .where((entry) => entry.value == maxVotes)
        .map((entry) => entry.key)
        .toList();

    if (candidates.length == 1) {
      // 单独出局
      final eliminated = candidates.first;
      await _eliminatePlayer(state, eliminated, voteDetails[eliminated] ?? []);
    } else {
      // 平票处理（简化为随机选择一个，实际应该有PK环节）
      final eliminated = _random.choice(candidates);
      GameEngineLogger.instance.info(
        GameLogCategory.phase,
        '平票情况，随机选择${eliminated.name}出局',
        metadata: {'eliminated': eliminated.name, 'reason': 'tie'},
      );
      await _eliminatePlayer(state, eliminated, voteDetails[eliminated] ?? []);
    }
  }

  /// 淘汰玩家
  Future<void> _eliminatePlayer(
    GameState state,
    GamePlayer player,
    List<GamePlayer> voters,
  ) async {
    GameEngineLogger.instance.info(
      GameLogCategory.player,
      '玩家 ${player.name} 被投票出局',
      metadata: {'eliminated': player.name, 'voterCount': voters.length},
    );

    // 创建投票出局事件（暂时注释掉，因为类型不匹配）
    // state.addEvent(VoteEvent(
    //   voter: voters.isNotEmpty ? voters.first : player, // 简化处理
    //   candidate: player,
    //   voteType: VoteType.normal,
    //   dayNumber: state.dayNumber,
    // ));

    // 设置玩家死亡
    player.die(DeathCause.vote, state);

    // 如果是猎人，可能触发开枪
    if (player.role.roleId == 'hunter') {
      await _handleHunterShoot(state, player);
    }
  }

  /// 处理猎人开枪
  Future<void> _handleHunterShoot(GameState state, GamePlayer hunter) async {
    // 简化处理，实际应该通过技能系统
    GameEngineLogger.instance.info(
      GameLogCategory.skill,
      '猎人 ${hunter.name} 可以开枪',
      metadata: {'hunter': hunter.name},
    );

    // 这里应该调用猎人的开枪技能
    // 为了简化，暂时跳过具体实现
  }

  /// 获取发言顺序
  List<GamePlayer> _getSpeakingOrder(GameState state) {
    final alivePlayers = state.alivePlayers;
    if (alivePlayers.isEmpty) return [];

    // 简化实现：随机打乱顺序
    final shuffled = List<GamePlayer>.from(alivePlayers);
    _random.shuffle(shuffled);

    final orderNames = shuffled.map((p) => p.name).join(' → ');
    GameEngineLogger.instance.debug(
      GameLogCategory.phase,
      '发言顺序：$orderNames',
      metadata: {'speakingOrder': shuffled.map((p) => p.name).toList()},
    );

    return shuffled;
  }
}
