import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/shared/random_helper.dart';

/// 玩家顺序服务
///
/// 负责管理游戏中玩家的行动顺序，包括：
/// - 获取玩家行动顺序
/// - 查找最后死亡的玩家
/// - 从指定起点重排序玩家
class PlayerOrderService {
  /// 获取玩家行动顺序
  ///
  /// [state] 游戏状态
  /// [players] 需要排序的玩家列表（通常为存活玩家）
  /// 返回按正确顺序排列的玩家列表
  List<Player> getActionOrder(GameState state, List<Player> players) {
    if (players.isEmpty) return [];

    return _getSpeakingOrder(state, players);
  }

  /// 查找最后死亡的玩家
  ///
  /// [state] 游戏状态
  /// 返回最后死亡玩家的信息，如果没有则返回null
  Player? findLastDeadPlayer(GameState state) {
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

  /// 从指定起始点重排序玩家
  ///
  /// [allPlayersSorted] 已排序的所有玩家列表
  /// [playersToOrder] 需要重排序的玩家列表
  /// [startingIndex] 起始索引
  /// 返回从起始点开始重排序的玩家列表
  List<Player> reorderFromStartingPoint(
    List<Player> allPlayersSorted,
    List<Player> playersToOrder,
    int startingIndex,
  ) {
    final orderedPlayers = <Player>[];
    final playerNamesToOrder = playersToOrder.map((p) => p.name).toSet();

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
        if (playerNamesToOrder.contains(player.name)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    } else {
      // 正序
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex = (startingIndex + i) % allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (playerNamesToOrder.contains(player.name)) {
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

  /// 获取玩家发言顺序（私有方法，用于内部实现）
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
    final Player? lastDeadPlayer = findLastDeadPlayer(state);

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

    return reorderFromStartingPoint(
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
      return reorderFromStartingPoint(allPlayersSorted, alivePlayers, 0);
    }

    // 确定起始点（死亡玩家的下一位）
    int startingIndex = (deadPlayerIndex + 1) % allPlayersSorted.length;

    // 从该位置开始找到下一个存活的玩家
    for (int i = 0; i < allPlayersSorted.length; i++) {
      final currentIndex = (startingIndex + i) % allPlayersSorted.length;
      final currentPlayer = allPlayersSorted[currentIndex];
      if (currentPlayer.isAlive) {
        return reorderFromStartingPoint(
          allPlayersSorted,
          alivePlayers,
          currentIndex,
        );
      }
    }

    // 不应该到这里，但以防万一
    return reorderFromStartingPoint(allPlayersSorted, alivePlayers, 0);
  }
}