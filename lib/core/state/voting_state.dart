import 'package:werewolf_arena/core/domain/entities/player.dart';

/// 投票记录类
class VoteRecord {
  final String voterName;
  final String targetName;

  VoteRecord({
    required this.voterName,
    required this.targetName,
  });

  /// 为了兼容旧代码的getter
  String get voter => voterName;
  String get target => targetName;
}

/// 投票状态管理类
///
/// 负责管理游戏投票阶段的各种状态，包括投票收集、结果统计、平票处理等。
/// 这个类封装了投票相关的逻辑，使用组合模式与 GameState 配合使用。
///
/// 主要功能：
/// - 收集和存储玩家的投票
/// - 统计投票结果
/// - 判断是否存在平票
/// - 获取投票出局的玩家或平票玩家列表
/// - 提供状态清理和序列化功能
///
/// 使用示例：
/// ```dart
/// final votingState = VotingState();
/// votingState.addVote(voter1, target1);
/// votingState.addVote(voter2, target1);
///
/// // 获取投票结果
/// final results = votingState.getVoteResults();
/// final eliminated = votingState.getVoteTarget(alivePlayers);
/// final tiedPlayers = votingState.getTiedPlayers(alivePlayers);
/// ```
class VotingState {
  Map<String, String> votes;
  bool _isPkPhase = false;
  List<Player> _pkCandidates = [];
  Set<String> _confirmedVotes = {};
  Set<String> _pkSpokenPlayers = {};
  bool allowVoteChange = true;
  bool allowAbstain = true;

  VotingState({
    Map<String, String>? votes,
    bool isPkPhase = false,
    List<Player>? pkCandidates,
    Set<String>? confirmedVotes,
    Set<String>? pkSpokenPlayers,
    this.allowVoteChange = true,
    this.allowAbstain = true,
  }) : votes = votes ?? {},
       _isPkPhase = isPkPhase,
       _pkCandidates = pkCandidates ?? [],
       _confirmedVotes = confirmedVotes ?? {},
       _pkSpokenPlayers = pkSpokenPlayers ?? {};

  int get totalVotes => votes.length;

  /// PK阶段相关getter和setter
  bool get isPkPhase => _isPkPhase;
  set isPkPhase(bool value) => _isPkPhase = value;
  
  List<Player> get pkCandidates => List.unmodifiable(_pkCandidates);
  set pkCandidates(List<Player> candidates) => _pkCandidates = [...candidates];

  /// 投票管理方法
  List<VoteRecord> getCurrentVotes() {
    return votes.entries.map((entry) => 
      VoteRecord(voterName: entry.key, targetName: entry.value)
    ).toList();
  }

  bool isVoteConfirmed(Player player) {
    return _confirmedVotes.contains(player.name);
  }

  void confirmVote(Player player) {
    _confirmedVotes.add(player.name);
  }

  /// PK发言管理
  bool hasPlayerSpokenInPk(Player player) {
    return _pkSpokenPlayers.contains(player.name);
  }

  void markPlayerSpokenInPk(Player player) {
    _pkSpokenPlayers.add(player.name);
  }

  /// 清理方法
  void clearPkData() {
    _isPkPhase = false;
    _pkCandidates.clear();
    _pkSpokenPlayers.clear();
  }

  void clearConfirmations() {
    _confirmedVotes.clear();
  }

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
      'isPkPhase': _isPkPhase,
      'pkCandidates': _pkCandidates.map((p) => p.name).toList(),
      'confirmedVotes': _confirmedVotes.toList(),
      'pkSpokenPlayers': _pkSpokenPlayers.toList(),
      'allowVoteChange': allowVoteChange,
      'allowAbstain': allowAbstain,
    };
  }

  factory VotingState.fromJson(Map<String, dynamic> json, List<Player> allPlayers) {
    final pkCandidateNames = List<String>.from(json['pkCandidates'] ?? []);
    final pkCandidates = pkCandidateNames
        .map((name) => _playerFromName(allPlayers, name))
        .whereType<Player>()
        .toList();

    return VotingState(
      votes: Map<String, String>.from(json['votes'] ?? {}),
      isPkPhase: json['isPkPhase'] ?? false,
      pkCandidates: pkCandidates,
      confirmedVotes: Set<String>.from(json['confirmedVotes'] ?? []),
      pkSpokenPlayers: Set<String>.from(json['pkSpokenPlayers'] ?? []),
      allowVoteChange: json['allowVoteChange'] ?? true,
      allowAbstain: json['allowAbstain'] ?? true,
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
