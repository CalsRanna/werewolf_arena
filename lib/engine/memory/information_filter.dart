import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/memory/working_memory.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 信息过滤器
///
/// 从大量游戏事件中筛选出关键信息，避免信息过载
/// 这是CoT（Chain of Thought）推理的第一步
class InformationFilter {
  /// 识别当前的核心矛盾
  ///
  /// 例如："3号和7号都跳预言家，谁是真预言家？"
  String identifyCoreConflict(GameState state, GamePlayer currentPlayer) {
    // 优先级1：预言家对跳
    final seerClaims = _findSeerClaims(state);
    if (seerClaims.length >= 2) {
      final players = seerClaims.join('和');
      return '$players都声称是预言家，需要判断谁是真预言家';
    }

    // 优先级2：被多人怀疑的玩家
    final suspectedPlayers = _findSuspectedPlayers(state);
    if (suspectedPlayers.isNotEmpty) {
      return '${suspectedPlayers.first}被多人怀疑，需要判断其身份';
    }

    // 优先级3：投票分歧
    if (state.day > 1) {
      return '需要确定今天的投票目标，推进游戏进程';
    }

    // 默认：观察期
    return '当前处于信息收集阶段，需要观察各方表现';
  }

  /// 提取关键事实
  ///
  /// 从事件历史中提取最重要的事实，限制数量避免过载
  List<KeyFact> extractKeyFacts(
    GameState state,
    GamePlayer currentPlayer, {
    int limit = 5,
  }) {
    final facts = <KeyFact>[];

    // 可见的事件
    final visibleEvents = state.events
        .where((event) => event.isVisibleTo(currentPlayer))
        .toList();

    for (final event in visibleEvents) {
      final fact = _eventToKeyFact(event, state);
      if (fact != null) {
        facts.add(fact);
      }
    }

    // 按重要性排序
    facts.sort((a, b) => b.importance.compareTo(a.importance));

    return facts.take(limit).toList();
  }

  /// 识别需要重点关注的玩家
  ///
  /// 最多返回3个玩家，避免注意力分散
  List<String> identifyFocusPlayers(
    GameState state,
    GamePlayer currentPlayer, {
    int limit = 3,
  }) {
    final focusPlayers = <_PlayerScore>[];

    for (final player in state.alivePlayers) {
      if (player.id == currentPlayer.id) continue;

      int score = 0;

      // 优先级1：声称是预言家的玩家
      if (_hasClaimedSeer(player, state)) {
        score += 100;
      }

      // 优先级2：最近发言攻击自己的玩家
      if (_hasAttackedMe(player, currentPlayer, state)) {
        score += 80;
      }

      // 优先级3：被多人怀疑的玩家
      final suspicionCount = _getSuspicionCount(player, state);
      score += suspicionCount * 20;

      // 优先级4：最近发言的玩家
      if (_hasRecentlySpoken(player, state)) {
        score += 10;
      }

      if (score > 0) {
        focusPlayers.add(_PlayerScore(player.name, score));
      }
    }

    // 按分数排序
    focusPlayers.sort((a, b) => b.score.compareTo(a.score));

    return focusPlayers.take(limit).map((p) => p.playerName).toList();
  }

  /// 过滤并构建精简的上下文
  ///
  /// 将大量事件转换为精简的文本描述
  String buildFilteredContext(
    GameState state,
    GamePlayer currentPlayer,
    WorkingMemory memory,
  ) {
    final buffer = StringBuffer();

    // 核心矛盾
    final coreConflict = identifyCoreConflict(state, currentPlayer);
    buffer.writeln('## 当前核心矛盾');
    buffer.writeln(coreConflict);
    buffer.writeln();

    // 关键事实
    final keyFacts = extractKeyFacts(state, currentPlayer, limit: 5);
    if (keyFacts.isNotEmpty) {
      buffer.writeln('## 关键事实');
      for (var i = 0; i < keyFacts.length; i++) {
        buffer.writeln('${i + 1}. ${keyFacts[i].description}');
      }
      buffer.writeln();
    }

    // 重点关注玩家
    final focusPlayers = identifyFocusPlayers(state, currentPlayer, limit: 3);
    if (focusPlayers.isNotEmpty) {
      buffer.writeln('## 重点关注玩家');
      buffer.writeln(focusPlayers.join(', '));
      buffer.writeln();
    }

    // 局势概况
    buffer.writeln('## 局势概况');
    buffer.writeln('- 当前第${state.day}天');
    buffer.writeln('- 存活玩家：${state.alivePlayers.length}人');
    buffer.writeln(
        '- 出局玩家：${state.deadPlayers.map((p) => p.name).join(", ")}');

    return buffer.toString();
  }

  // ===== 私有辅助方法 =====

  /// 查找声称是预言家的玩家
  List<String> _findSeerClaims(GameState state) {
    final claims = <String>[];
    // TODO: 实现通过发言事件识别预言家声明
    // 需要解析发言内容，识别"我是预言家"等关键词
    return claims;
  }

  /// 查找被多人怀疑的玩家
  List<String> _findSuspectedPlayers(GameState state) {
    final suspected = <String>[];
    // TODO: 实现通过发言和投票统计被怀疑的玩家
    return suspected;
  }

  /// 检查玩家是否声称是预言家
  bool _hasClaimedSeer(GamePlayer player, GameState state) {
    // TODO: 通过发言历史判断
    return false;
  }

  /// 检查玩家是否攻击过我
  bool _hasAttackedMe(
    GamePlayer player,
    GamePlayer me,
    GameState state,
  ) {
    // TODO: 分析发言和投票记录
    return false;
  }

  /// 获取玩家被怀疑的次数
  int _getSuspicionCount(GamePlayer player, GameState state) {
    // TODO: 统计针对该玩家的怀疑发言数量
    return 0;
  }

  /// 检查玩家是否最近发言过
  bool _hasRecentlySpoken(GamePlayer player, GameState state) {
    final recentEvents = state.events.reversed.take(10);
    // 简化实现：通过事件叙述判断是否提到该玩家发言
    return recentEvents.any(
      (e) {
        final narrative = e.toNarrative();
        return narrative.contains(player.name) && narrative.contains('说');
      },
    );
  }

  /// 将事件转换为关键事实
  KeyFact? _eventToKeyFact(GameEvent event, GameState state) {
    final narrative = event.toNarrative();

    // 死亡事件
    if (narrative.contains('死亡') || narrative.contains('出局')) {
      return KeyFact(
        description: narrative,
        importance: 90,
        day: event.day,
      );
    }

    // 其他事件权重较低
    return null;
  }
}

/// 玩家评分（用于排序）
class _PlayerScore {
  final String playerName;
  final int score;

  _PlayerScore(this.playerName, this.score);
}
