/// 玩家间的关系
///
/// 记录一个玩家对另一个玩家的看法和关系强度
class Relationship {
  /// 关系的主体（谁的看法）
  final String fromPlayerId;

  /// 关系的客体（对谁的看法）
  final String toPlayerId;

  /// 信任度 (-100 到 100)
  /// -100: 完全不信任/确定是狼
  /// 0: 中立/不确定
  /// 100: 完全信任/确定是好人
  final double trustLevel;

  /// 怀疑度 (0 到 100)
  /// 0: 没有怀疑
  /// 100: 高度怀疑
  final double suspicionLevel;

  /// 关系类型
  final RelationshipType type;

  /// 关系强度 (0 到 1)
  /// 表示这个关系的重要性/确定性
  final double strength;

  /// 关系建立的依据
  final List<String> evidences;

  /// 最后更新时间
  final DateTime lastUpdated;

  const Relationship({
    required this.fromPlayerId,
    required this.toPlayerId,
    required this.trustLevel,
    required this.suspicionLevel,
    required this.type,
    required this.strength,
    required this.evidences,
    required this.lastUpdated,
  });

  /// 创建初始关系（中立）
  factory Relationship.neutral({
    required String fromPlayerId,
    required String toPlayerId,
  }) {
    return Relationship(
      fromPlayerId: fromPlayerId,
      toPlayerId: toPlayerId,
      trustLevel: 0,
      suspicionLevel: 0,
      type: RelationshipType.neutral,
      strength: 0.0,
      evidences: [],
      lastUpdated: DateTime.now(),
    );
  }

  /// 创建盟友关系
  factory Relationship.ally({
    required String fromPlayerId,
    required String toPlayerId,
    required double trustLevel,
    required List<String> evidences,
  }) {
    return Relationship(
      fromPlayerId: fromPlayerId,
      toPlayerId: toPlayerId,
      trustLevel: trustLevel,
      suspicionLevel: 0,
      type: RelationshipType.ally,
      strength: trustLevel.abs() / 100,
      evidences: evidences,
      lastUpdated: DateTime.now(),
    );
  }

  /// 创建敌对关系
  factory Relationship.enemy({
    required String fromPlayerId,
    required String toPlayerId,
    required double suspicionLevel,
    required List<String> evidences,
  }) {
    return Relationship(
      fromPlayerId: fromPlayerId,
      toPlayerId: toPlayerId,
      trustLevel: -suspicionLevel,
      suspicionLevel: suspicionLevel,
      type: RelationshipType.enemy,
      strength: suspicionLevel / 100,
      evidences: evidences,
      lastUpdated: DateTime.now(),
    );
  }

  /// 更新关系
  Relationship update({
    double? trustLevel,
    double? suspicionLevel,
    RelationshipType? type,
    double? strength,
    List<String>? evidences,
  }) {
    return Relationship(
      fromPlayerId: fromPlayerId,
      toPlayerId: toPlayerId,
      trustLevel: trustLevel ?? this.trustLevel,
      suspicionLevel: suspicionLevel ?? this.suspicionLevel,
      type: type ?? this.type,
      strength: strength ?? this.strength,
      evidences: evidences ?? this.evidences,
      lastUpdated: DateTime.now(),
    );
  }

  /// 添加新证据
  Relationship addEvidence(String evidence) {
    return Relationship(
      fromPlayerId: fromPlayerId,
      toPlayerId: toPlayerId,
      trustLevel: trustLevel,
      suspicionLevel: suspicionLevel,
      type: type,
      strength: strength,
      evidences: [...evidences, evidence],
      lastUpdated: DateTime.now(),
    );
  }

  /// 判断是否为强关系（重要关系）
  bool get isStrong => strength > 0.5;

  /// 判断是否为盟友
  bool get isAlly => type == RelationshipType.ally || trustLevel > 30;

  /// 判断是否为敌人
  bool get isEnemy => type == RelationshipType.enemy || suspicionLevel > 50;

  /// 关系描述
  String get description {
    if (trustLevel > 70) return '坚定盟友';
    if (trustLevel > 30) return '倾向信任';
    if (trustLevel < -70) return '确定敌人';
    if (suspicionLevel > 70) return '高度怀疑';
    if (suspicionLevel > 30) return '轻度怀疑';
    return '中立';
  }

  /// 转换为Prompt文本
  String toPrompt(String toPlayerName) {
    final buffer = StringBuffer();
    buffer.write('对$toPlayerName: ');
    buffer.write(description);

    if (evidences.isNotEmpty) {
      buffer.write(' (依据: ${evidences.take(3).join('; ')})');
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'Relationship(from: $fromPlayerId, to: $toPlayerId, '
        'trust: $trustLevel, suspicion: $suspicionLevel, '
        'type: $type, strength: $strength)';
  }
}

/// 关系类型
enum RelationshipType {
  /// 盟友
  ally,

  /// 敌人
  enemy,

  /// 中立
  neutral,

  /// 不确定
  uncertain,
}
