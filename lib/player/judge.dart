import '../utils/logger_util.dart';

/// Judge role - responsible for game notifications and speech history recording
class Judge {
  Judge({required this.gameId});

  final String gameId;

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
    LoggerUtil.instance.i(
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
    LoggerUtil.instance.i('[Judge Announce] Game started with $playerCount participants');
  }

  /// Announce night start
  void announceNightStart(int dayNumber) {
    final message = '''
🌙 ===== NIGHT $dayNumber =====
Night falls, please close your eyes. God roles begin to act
=========================
''';

    print(message);
    LoggerUtil.instance.i('[Judge Announce] Night $dayNumber begins');
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
    LoggerUtil.instance.i(
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
    LoggerUtil.instance.i('[Judge Announce] Voting phase begins');
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
    LoggerUtil.instance.i(
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
    LoggerUtil.instance.i('[Judge Announce] Game ended, winning faction: $winner');
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

  /// Announce werewolf phase
  void announceWerewolfPhase() {
    final message = '''
🐺 ===== WEREWOLF PHASE =====
Werewolves, please open your eyes
Discuss and choose your kill target
============================
''';

    print(message);
    LoggerUtil.instance.i('[Judge Announce] Werewolf phase begins');
  }

  /// Announce werewolf decision
  void announceWerewolfDecision(String? victimName) {
    if (victimName != null) {
      print('🐺 Werewolves have chosen their target: $victimName');
      LoggerUtil.instance.i('[Judge Announce] Werewolves chose: $victimName');
    } else {
      print('🐺 Werewolves chose no target tonight');
      LoggerUtil.instance.i('[Judge Announce] Werewolves chose no target');
    }
  }

  /// Announce guard phase
  void announceGuardPhase() {
    final message = '''
🛡️ ===== GUARD PHASE =====
Guard, please open your eyes
Choose someone to protect tonight
=========================
''';

    print(message);
    LoggerUtil.instance.i('[Judge Announce] Guard phase begins');
  }

  /// Announce guard decision
  void announceGuardDecision(String? protectedName) {
    if (protectedName != null) {
      print('🛡️ Guard chose to protect: $protectedName');
      LoggerUtil.instance.i('[Judge Announce] Guard protected: $protectedName');
    } else {
      print('🛡️ Guard chose not to protect anyone');
      LoggerUtil.instance.i('[Judge Announce] Guard chose no protection');
    }
  }

  /// Announce seer phase
  void announceSeerPhase() {
    final message = '''
🔮 ===== SEER PHASE =====
Seer, please open your eyes
Choose someone to investigate
=========================
''';

    print(message);
    LoggerUtil.instance.i('[Judge Announce] Seer phase begins');
  }

  /// Announce seer result
  void announceSeerResult(String targetName, bool isWerewolf) {
    final identity = isWerewolf ? 'a werewolf' : 'a good person';
    print('🔮 $targetName is $identity');
    LoggerUtil.instance.i('[Judge Announce] Seer investigated: $targetName is $identity');
  }

  /// Announce witch phase
  void announceWitchPhase(String? victimName) {
    String message = '''
💊 ===== WITCH PHASE =====
Witch, please open your eyes
''';

    if (victimName != null) {
      message += 'Tonight $victimName was killed\n';
      message += 'Do you want to use the heal potion?\n';
    } else {
      message += 'No one was killed tonight\n';
    }

    message += 'Do you want to use the poison potion?\n';
    message += '=========================';

    print(message);
    LoggerUtil.instance.i('[Judge Announce] Witch phase begins, victim: ${victimName ?? "none"}');
  }

  /// Announce witch decision
  void announceWitchDecision({bool healed = false, String? poisonedName}) {
    if (healed) {
      print('💊 Witch used heal potion');
      LoggerUtil.instance.i('[Judge Announce] Witch used heal potion');
    }
    if (poisonedName != null) {
      print('💊 Witch used poison on: $poisonedName');
      LoggerUtil.instance.i('[Judge Announce] Witch poisoned: $poisonedName');
    }
    if (!healed && poisonedName == null) {
      print('💊 Witch chose not to use any potions');
      LoggerUtil.instance.i('[Judge Announce] Witch used no potions');
    }
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
    LoggerUtil.instance.i('[Judge] Clear speech history records');
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
