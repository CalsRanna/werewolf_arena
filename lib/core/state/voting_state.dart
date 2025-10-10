import 'package:werewolf_arena/core/domain/entities/player.dart';

class VotingState {
  Map<String, String> votes;

  VotingState({
    Map<String, String>? votes,
  }) : votes = votes ?? {};

  int get totalVotes => votes.length;

  void addVote(Player voter, Player target) {
    votes[voter.name] = target.name;
  }

  void clearVotes() {
    votes.clear();
  }

  Map<String, int> getVoteResults() {
    final results = <String, int>{};
    for (final vote in votes.values) {
      results[vote] = (results[vote] ?? 0) + 1;
    }
    return results;
  }

  Player? getVoteTarget(List<Player> alivePlayers) {
    final results = getVoteResults();
    if (results.isEmpty) return null;

    int maxVotes = 0;
    List<String> tiedPlayers = [];

    for (final entry in results.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        tiedPlayers = [entry.key];
      } else if (entry.value == maxVotes) {
        tiedPlayers.add(entry.key);
      }
    }

    if (tiedPlayers.length > 1) {
      return null;
    }

    if (tiedPlayers.isNotEmpty && maxVotes > 0) {
      return _playerFromName(alivePlayers, tiedPlayers.first);
    }
    return null;
  }

  List<Player> getTiedPlayers(List<Player> alivePlayers) {
    final results = getVoteResults();
    if (results.isEmpty) return [];

    int maxVotes = 0;
    List<String> tiedPlayerNames = [];

    for (final entry in results.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        tiedPlayerNames = [entry.key];
      } else if (entry.value == maxVotes) {
        tiedPlayerNames.add(entry.key);
      }
    }

    if (tiedPlayerNames.length > 1) {
      return tiedPlayerNames
          .map((name) => _playerFromName(alivePlayers, name))
          .whereType<Player>()
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'votes': votes,
    };
  }

  factory VotingState.fromJson(Map<String, dynamic> json) {
    return VotingState(
      votes: Map<String, String>.from(json['votes'] ?? {}),
    );
  }

  static Player? _playerFromName(List<Player> players, String? name) {
    if (name == null) return null;
    try {
      return players.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }
}
