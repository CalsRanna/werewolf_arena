/// 胜利结果类
/// 
/// 用于表示游戏胜利条件检查的结果
class VictoryResult {
  /// 获胜方，null表示游戏继续
  final String? winner;
  
  /// 胜利原因
  final String reason;

  const VictoryResult({
    required this.winner,
    required this.reason,
  });

  /// 游戏继续（没有胜利方）
  factory VictoryResult.gameContinues() {
    return const VictoryResult(
      winner: null,
      reason: '游戏继续',
    );
  }

  /// 好人阵营胜利
  factory VictoryResult.goodWins(String reason) {
    return VictoryResult(
      winner: '好人阵营',
      reason: reason,
    );
  }

  /// 狼人阵营胜利
  factory VictoryResult.evilWins(String reason) {
    return VictoryResult(
      winner: '狼人阵营',
      reason: reason,
    );
  }

  /// 游戏是否已结束
  bool get isGameEnded => winner != null;

  /// 游戏是否继续
  bool get isGameContinues => winner == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VictoryResult &&
          runtimeType == other.runtimeType &&
          winner == other.winner &&
          reason == other.reason;

  @override
  int get hashCode => winner.hashCode ^ reason.hashCode;

  @override
  String toString() {
    return 'VictoryResult{winner: $winner, reason: $reason}';
  }
}