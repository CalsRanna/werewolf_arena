import '../utils/game_logger.dart';

/// Judge role - responsible for game notifications and speech history recording
class Judge {
  Judge({required this.gameId, required this.logger});

  final String gameId;
  final GameLogger logger;

  /// Speech history record
  final List<SpeechRecord> speechHistory = [];

  /// Record player speech
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
    logger.info(
        '[Judge Record] $playerName($roleName) spoke on day $dayNumber in $phase phase');
  }

  /// Announce game start
  void announceGameStart(int playerCount) {
    final message = '''
🎯 ===== GAME START =====
Participants: $playerCount players
Judge is in position, game recording begins
Please follow the rules and start the game
========================
''';

    print(message);
    logger.info('[Judge Announce] Game started with $playerCount participants');
  }

  /// Announce night start
  void announceNightStart(int dayNumber) {
    final message = '''
🌙 ===== NIGHT $dayNumber =====
Night falls, please close your eyes. God roles begin to act
=========================
''';

    print(message);
    logger.info('[Judge Announce] Night $dayNumber begins');
  }

  /// Announce day start and night results
  void announceDayStart(int dayNumber, List<String> deaths) {
    String message = '''
☀️ ===== DAY $dayNumber =====
Daybreak! The following events occurred last night:
''';

    if (deaths.isEmpty) {
      message += '🎉 Peaceful night, no deaths\n';
    } else {
      for (final death in deaths) {
        message += '💀 $death\n';
      }
    }

    message += 'Please begin discussion\n=========================';

    print(message);
    logger.info(
        '[Judge Announce] Day $dayNumber begins, deaths: ${deaths.join(", ")}');
  }

  /// Announce voting phase
  void announceVotingPhase() {
    final message = '''
🗳️ ===== VOTING PHASE =====
Please vote for the person to be executed
=======================
''';

    print(message);
    logger.info('[Judge Announce] Voting phase begins');
  }

  /// Announce voting results
  void announceVotingResult(
      String? executedPlayer, Map<String, int> voteResults) {
    String message = '''
📊 ===== VOTING RESULTS =====
''';

    voteResults.forEach((playerId, votes) {
      message += '$playerId: $votes votes\n';
    });

    if (executedPlayer != null) {
      message += '\n⚰️ $executedPlayer was executed by vote\n';
    } else {
      message += '\n🤝 Vote inconclusive, no execution\n';
    }

    message += '=======================';

    print(message);
    logger.info(
        '[Judge Announce] Voting result: ${executedPlayer ?? "no execution"}');
  }

  /// Announce game end
  void announceGameEnd(String winner, Map<String, String> playerRoles) {
    String message = '''
🎊 ===== GAME END =====
🏆 Winning faction: $winner

Role reveals:
''';

    playerRoles.forEach((playerId, role) {
      message += '$playerId - $role\n';
    });

    message += '=======================';

    print(message);
    logger.info('[Judge Announce] Game ended, winning faction: $winner');
  }

  /// Get speech history (for LLM context)
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

  /// Get speech history text format (for LLM)
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

    if (history.isEmpty) return 'No speech records yet';

    return history.map((record) {
      return '[Day${record.dayNumber}-${record.phase}] ${record.playerName}: ${record.message}';
    }).join('\n');
  }

  /// Get current game statistics
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

  /// Clear history records
  void clearHistory() {
    speechHistory.clear();
    logger.info('[Judge] Clear speech history records');
  }
}

/// Speech record data class
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
    return '[Day$dayNumber-$phase] $playerName($roleName): $message';
  }

  /// Convert to JSON format
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

  /// Create from JSON
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
