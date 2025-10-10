import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/shared/random_helper.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/events/phase_events.dart';
import 'phase_processor.dart';

/// 白天阶段处理器
///
/// 负责处理游戏中的白天阶段，包括：
/// - 公布夜晚结果
/// - 玩家讨论发言
/// - 为投票阶段做准备
class DayPhaseProcessor implements PhaseProcessor {
  @override
  GamePhase get supportedPhase => GamePhase.day;

  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理白天阶段 - 第${state.dayNumber}天');

    // 公布夜晚结果
    await _announceNightResults(state);

    // 玩家讨论阶段
    await _runDiscussionPhase(state);

    // 切换到投票阶段
    await state.changePhase(GamePhase.voting);

    LoggerUtil.instance.d('白天阶段处理完成，准备进入投票阶段');
  }

  /// 公布夜晚结果
  Future<void> _announceNightResults(GameState state) async {
    LoggerUtil.instance.d('公布夜晚结果');

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
      LoggerUtil.instance.d('第${state.dayNumber}夜是平安夜，无人死亡');
    } else {
      final deadPlayers = deathEvents.map((e) => e.victim.name).join('、');
      LoggerUtil.instance.d('第${state.dayNumber}夜死亡玩家：$deadPlayers');
    }

    // 公布当前存活玩家
    final alivePlayers = state.alivePlayers;
    LoggerUtil.instance.d(
      '当前存活玩家：${alivePlayers.map((p) => p.name).join('、')}',
    );
  }

  /// 运行讨论阶段 - 玩家按顺序发言
  Future<void> _runDiscussionPhase(GameState state) async {
    LoggerUtil.instance.d('开始讨论阶段');

    // 获取发言顺序
    final speakingOrder = _getSpeakingOrder(state, state.alivePlayers);

    // 收集讨论历史
    final discussionHistory = <String>[];

    // 玩家依次发言
    for (int i = 0; i < speakingOrder.length; i++) {
      final player = speakingOrder[i];

      // 确保玩家仍然存活
      if (player is AIPlayer && player.isAlive) {
        try {
          LoggerUtil.instance.d('处理玩家 ${player.name} 的发言');

          // 更新玩家事件日志
          PlayerLogger.instance.updatePlayerEvents(player, state);

          // 处理信息以生成发言
          await player.processInformation(state);

          // 构建发言上下文
          String context = _buildDiscussionContext(discussionHistory);

          // 生成发言内容
          final statement = await player.generateStatement(state, context);

          if (statement.isNotEmpty) {
            // 创建发言事件
            final event = player.createSpeakEvent(statement, state);
            if (event != null) {
              player.executeEvent(event, state);

              // 添加到讨论历史
              discussionHistory.add('[${player.name}]: $statement');

              LoggerUtil.instance.d('玩家 ${player.name} 发言: $statement');
            } else {
              LoggerUtil.instance.debug('玩家 ${player.name} 无法创建发言事件');
            }
          } else {
            LoggerUtil.instance.debug('玩家 ${player.name} 未发言');
          }
        } catch (e) {
          LoggerUtil.instance.e('玩家 ${player.name} 发言失败: $e');
        }

        // 玩家间发言延迟
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    LoggerUtil.instance.d('讨论阶段结束，共${discussionHistory.length}位玩家发言');
  }

  /// 获取玩家发言顺序
  List<Player> _getSpeakingOrder(GameState state, List<Player> alivePlayers) {
    if (alivePlayers.isEmpty) return [];

    // 获取所有玩家并按编号排序
    final allPlayersSorted = List<Player>.from(state.players);
    allPlayersSorted.sort((a, b) {
      final aNum = int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final bNum = int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    // 查找最后死亡或出局的玩家
    final Player? lastDeadPlayer = _findLastDeadPlayer(state);

    if (lastDeadPlayer == null) {
      // 没有死亡参考点，随机选择起始点
      return _getRandomSpeakingOrder(allPlayersSorted, alivePlayers);
    }

    // 从最后死亡玩家的下一位开始
    return _getOrderFromDeadPlayer(
      allPlayersSorted,
      alivePlayers,
      lastDeadPlayer,
    );
  }

  /// 查找最后死亡的玩家
  Player? _findLastDeadPlayer(GameState state) {
    // 查找最近的死亡事件（包括投票出局）
    final deathEvents = state.eventHistory
        .where((e) => e.type.name == 'playerDeath')
        .toList();

    if (deathEvents.isNotEmpty) {
      // 按时间戳排序，获取最近的
      deathEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final lastEvent = deathEvents.first;
      return lastEvent.target ?? lastEvent.initiator;
    }

    return null; // 还没有死亡事件
  }

  /// 随机获取发言顺序
  List<Player> _getRandomSpeakingOrder(
    List<Player> allPlayersSorted,
    List<Player> alivePlayers,
  ) {
    final aliveIndices = <int>[];
    for (int i = 0; i < allPlayersSorted.length; i++) {
      if (allPlayersSorted[i].isAlive) {
        aliveIndices.add(i);
      }
    }

    if (aliveIndices.isEmpty) return [];

    // 随机选择起始点
    final randomIndex =
        aliveIndices[RandomHelper().nextInt(aliveIndices.length)];
    final startingPlayer = allPlayersSorted[randomIndex];

    LoggerUtil.instance.d('随机选择 ${startingPlayer.name} 作为发言起始点');

    return _reorderFromStartingPoint(
      allPlayersSorted,
      alivePlayers,
      randomIndex,
    );
  }

  /// 从死亡玩家开始获取发言顺序
  List<Player> _getOrderFromDeadPlayer(
    List<Player> allPlayersSorted,
    List<Player> alivePlayers,
    Player lastDeadPlayer,
  ) {
    // 在排序后的列表中查找死亡玩家的索引
    final deadPlayerIndex = allPlayersSorted.indexWhere(
      (p) => p.name == lastDeadPlayer.name,
    );

    if (deadPlayerIndex == -1) {
      // 出现问题，回退到正常排序
      return _reorderFromStartingPoint(allPlayersSorted, alivePlayers, 0);
    }

    // 确定起始点（死亡玩家的下一位）
    int startingIndex = (deadPlayerIndex + 1) % allPlayersSorted.length;

    // 从该位置开始找到下一个存活的玩家
    for (int i = 0; i < allPlayersSorted.length; i++) {
      final currentIndex = (startingIndex + i) % allPlayersSorted.length;
      final currentPlayer = allPlayersSorted[currentIndex];
      if (currentPlayer.isAlive) {
        return _reorderFromStartingPoint(
          allPlayersSorted,
          alivePlayers,
          currentIndex,
        );
      }
    }

    // 不应该到这里，但以防万一
    return _reorderFromStartingPoint(allPlayersSorted, alivePlayers, 0);
  }

  /// 从指定索引重新排序玩家
  List<Player> _reorderFromStartingPoint(
    List<Player> allPlayersSorted,
    List<Player> alivePlayers,
    int startingIndex,
  ) {
    final orderedPlayers = <Player>[];
    final alivePlayerNames = alivePlayers.map((p) => p.name).toSet();

    // 构建用于记录的顺序字符串
    final orderNames = <String>[];
    final isReverse = RandomHelper().nextBool();

    if (isReverse) {
      // 逆序
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex =
            (startingIndex - i + allPlayersSorted.length) %
            allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (alivePlayerNames.contains(player.name)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    } else {
      // 正序
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex = (startingIndex + i) % allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (alivePlayerNames.contains(player.name)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    }

    // 记录发言顺序
    final direction = isReverse ? "逆序" : "顺序";
    LoggerUtil.instance.d('从${orderNames.first}开始$direction发言');
    LoggerUtil.instance.d('发言顺序：${orderNames.join(' → ')}');

    return orderedPlayers;
  }

  /// 构建讨论上下文
  String _buildDiscussionContext(List<String> discussionHistory) {
    String context =
        'Day discussion phase, please share your views based on previous players\' statements.';

    if (discussionHistory.isNotEmpty) {
      context +=
          '\n\nPrevious players\' statements:\n${discussionHistory.join('\n')}';
    }

    context +=
        '\n\nNow it\'s your turn to speak, please share your views on the current situation and other players\' opinions:';

    return context;
  }
}
