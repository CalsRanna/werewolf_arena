import '../utils/game_logger.dart';

/// 法官角色 - 负责游戏通知和记录发言历史
class Judge {
  Judge({
    required this.gameId,
    required this.logger,
  });

  final String gameId;
  final GameLogger logger;

  /// 发言历史记录
  final List<SpeechRecord> speechHistory = [];

  /// 记录玩家发言
  void recordSpeech({
    required String playerId,
    required String playerName,
    required String roleName,
    required String message,
    required String phase,
    required int dayNumber,
  }) {
    final record = SpeechRecord(
      playerId: playerId,
      playerName: playerName,
      roleName: roleName,
      message: message,
      phase: phase,
      dayNumber: dayNumber,
      timestamp: DateTime.now(),
    );

    speechHistory.add(record);
    logger.info('[法官记录] $playerName($roleName) 在第$dayNumber天$phase阶段发言');
  }

  /// 宣布游戏开始
  void announceGameStart(int playerCount) {
    final message = '''
🎯 ===== 游戏开始 =====
参与玩家: $playerCount人
法官已就位，开始记录游戏过程
请各位玩家按照规则进行游戏
========================
''';

    print(message);
    logger.info('[法官宣布] 游戏开始，$playerCount人参与');
  }

  /// 宣布夜晚开始
  void announceNightStart(int dayNumber) {
    final message = '''
🌙 ===== 第$dayNumber夜 =====
天黑请闭眼，神职玩家开始行动
=========================
''';

    print(message);
    logger.info('[法官宣布] 第$dayNumber夜开始');
  }

  /// 宣布白天开始和夜晚结果
  void announceDayStart(int dayNumber, List<String> deaths) {
    String message = '''
☀️ ===== 第$dayNumber天 =====
天亮了，昨晚发生了以下事件：
''';

    if (deaths.isEmpty) {
      message += '🎉 平安夜，无人死亡\n';
    } else {
      for (final death in deaths) {
        message += '💀 $death\n';
      }
    }

    message += '请各位玩家开始讨论\n=========================';

    print(message);
    logger.info('[法官宣布] 第$dayNumber天开始，死亡: ${deaths.join(", ")}');
  }

  /// 宣布投票阶段
  void announceVotingPhase() {
    final message = '''
🗳️ ===== 投票阶段 =====
请各位玩家投票选出要处决的人
=======================
''';

    print(message);
    logger.info('[法官宣布] 投票阶段开始');
  }

  /// 宣布投票结果
  void announceVotingResult(
      String? executedPlayer, Map<String, int> voteResults) {
    String message = '''
📊 ===== 投票结果 =====
''';

    voteResults.forEach((playerId, votes) {
      message += '$playerId: $votes票\n';
    });

    if (executedPlayer != null) {
      message += '\n⚰️ $executedPlayer 被投票处决\n';
    } else {
      message += '\n🤝 投票未达成一致，无人被处决\n';
    }

    message += '=======================';

    print(message);
    logger.info('[法官宣布] 投票结果：${executedPlayer ?? "无人被处决"}');
  }

  /// 宣布游戏结束
  void announceGameEnd(String winner, Map<String, String> playerRoles) {
    String message = '''
🎊 ===== 游戏结束 =====
🏆 获胜阵营: $winner

身份揭晓：
''';

    playerRoles.forEach((playerId, role) {
      message += '$playerId - $role\n';
    });

    message += '=======================';

    print(message);
    logger.info('[法官宣布] 游戏结束，获胜阵营: $winner');
  }

  /// 获取发言历史（用于LLM上下文）
  List<SpeechRecord> getSpeechHistory({
    int? fromDay,
    String? phase,
    int? limit,
  }) {
    var filteredHistory = speechHistory.where((record) {
      if (fromDay != null && record.dayNumber < fromDay) return false;
      if (phase != null && record.phase != phase) return false;
      return true;
    }).toList();

    if (limit != null && filteredHistory.length > limit) {
      filteredHistory = filteredHistory.sublist(filteredHistory.length - limit);
    }

    return filteredHistory;
  }

  /// 获取发言历史文本格式（用于LLM）
  String getSpeechHistoryText({
    int? fromDay,
    String? phase,
    int? limit,
  }) {
    final history = getSpeechHistory(
      fromDay: fromDay,
      phase: phase,
      limit: limit,
    );

    if (history.isEmpty) return '暂无发言记录';

    return history.map((record) {
      return '[第${record.dayNumber}天-${record.phase}] ${record.playerName}: ${record.message}';
    }).join('\n');
  }

  /// 获取当前游戏统计
  Map<String, dynamic> getGameStats() {
    final totalSpeeches = speechHistory.length;
    final speechesByPhase = <String, int>{};
    final speechesByPlayer = <String, int>{};

    for (final record in speechHistory) {
      speechesByPhase[record.phase] = (speechesByPhase[record.phase] ?? 0) + 1;
      speechesByPlayer[record.playerName] =
          (speechesByPlayer[record.playerName] ?? 0) + 1;
    }

    return {
      'totalSpeeches': totalSpeeches,
      'speechesByPhase': speechesByPhase,
      'speechesByPlayer': speechesByPlayer,
      'gameId': gameId,
    };
  }

  /// 清空历史记录
  void clearHistory() {
    speechHistory.clear();
    logger.info('[法官] 清空发言历史记录');
  }
}

/// 发言记录数据类
class SpeechRecord {
  SpeechRecord({
    required this.playerId,
    required this.playerName,
    required this.roleName,
    required this.message,
    required this.phase,
    required this.dayNumber,
    required this.timestamp,
  });

  final String playerId;
  final String playerName;
  final String roleName;
  final String message;
  final String phase;
  final int dayNumber;
  final DateTime timestamp;

  @override
  String toString() {
    return '[$dayNumber天-$phase] $playerName($roleName): $message';
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'roleName': roleName,
      'message': message,
      'phase': phase,
      'dayNumber': dayNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 从JSON创建
  factory SpeechRecord.fromJson(Map<String, dynamic> json) {
    return SpeechRecord(
      playerId: json['playerId'],
      playerName: json['playerName'],
      roleName: json['roleName'],
      message: json['message'],
      phase: json['phase'],
      dayNumber: json['dayNumber'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
