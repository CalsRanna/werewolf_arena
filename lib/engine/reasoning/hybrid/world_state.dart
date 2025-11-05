/// 世界状态
///
/// 结构化的游戏状态，用于阶段一预处理的输出
/// 包含所有关键事实、社交关系等信息
class WorldState {
  /// 玩家自身信息
  final PlayerSelfInfo selfInfo;

  /// 其他玩家信息列表
  final List<OtherPlayerInfo> otherPlayers;

  /// 关键事件列表（按时间排序）
  final List<KeyEvent> keyEvents;

  /// 社交关系网络
  final SocialRelationships socialRelationships;

  /// 当前局势摘要
  final String situationSummary;

  /// 核心矛盾
  final String? coreConflict;

  WorldState({
    required this.selfInfo,
    required this.otherPlayers,
    required this.keyEvents,
    required this.socialRelationships,
    required this.situationSummary,
    this.coreConflict,
  });

  Map<String, dynamic> toJson() {
    return {
      'self_info': selfInfo.toJson(),
      'other_players': otherPlayers.map((p) => p.toJson()).toList(),
      'key_events': keyEvents.map((e) => e.toJson()).toList(),
      'social_relationships': socialRelationships.toJson(),
      'situation_summary': situationSummary,
      'core_conflict': coreConflict,
    };
  }

  factory WorldState.fromJson(Map<String, dynamic> json) {
    return WorldState(
      selfInfo: PlayerSelfInfo.fromJson(json['self_info']),
      otherPlayers: (json['other_players'] as List)
          .map((p) => OtherPlayerInfo.fromJson(p))
          .toList(),
      keyEvents: (json['key_events'] as List)
          .map((e) => KeyEvent.fromJson(e))
          .toList(),
      socialRelationships:
          SocialRelationships.fromJson(json['social_relationships']),
      situationSummary: json['situation_summary'],
      coreConflict: json['core_conflict'],
    );
  }
}

/// 玩家自身信息
class PlayerSelfInfo {
  /// 玩家名称（如"5号玩家"）
  final String name;

  /// 玩家号码（如"5"）
  final String number;

  /// 真实角色
  final String role;

  /// 阵营（"好人"或"狼人"）
  final String faction;

  /// 队友列表（仅狼人有）
  final List<String> teammates;

  /// 秘密信息（如查验结果、守护历史等）
  final Map<String, dynamic> secretKnowledge;

  PlayerSelfInfo({
    required this.name,
    required this.number,
    required this.role,
    required this.faction,
    this.teammates = const [],
    this.secretKnowledge = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'role': role,
      'faction': faction,
      'teammates': teammates,
      'secret_knowledge': secretKnowledge,
    };
  }

  factory PlayerSelfInfo.fromJson(Map<String, dynamic> json) {
    return PlayerSelfInfo(
      name: json['name'] as String,
      // 容忍数字类型的number字段
      number: json['number'] is int
          ? json['number'].toString()
          : json['number'] as String,
      role: json['role'] as String,
      faction: json['faction'] as String,
      teammates: (json['teammates'] as List?)?.cast<String>() ?? [],
      secretKnowledge:
          (json['secret_knowledge'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// 其他玩家信息
class OtherPlayerInfo {
  /// 玩家名称
  final String name;

  /// 是否存活
  final bool isAlive;

  /// 推测的角色（如果有）
  final String? estimatedRole;

  /// 推测置信度（0-100）
  final int? estimatedConfidence;

  /// 关键发言摘要
  final List<String> keySpeechSummary;

  OtherPlayerInfo({
    required this.name,
    required this.isAlive,
    this.estimatedRole,
    this.estimatedConfidence,
    this.keySpeechSummary = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'is_alive': isAlive,
      'estimated_role': estimatedRole,
      'estimated_confidence': estimatedConfidence,
      'key_speech_summary': keySpeechSummary,
    };
  }

  factory OtherPlayerInfo.fromJson(Map<String, dynamic> json) {
    return OtherPlayerInfo(
      name: json['name'] as String,
      isAlive: json['is_alive'] as bool,
      estimatedRole: json['estimated_role'] as String?,
      // 容忍浮点数类型的confidence
      estimatedConfidence: json['estimated_confidence'] is num
          ? (json['estimated_confidence'] as num).toInt()
          : json['estimated_confidence'] as int?,
      keySpeechSummary:
          (json['key_speech_summary'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 关键事件
class KeyEvent {
  /// 事件描述
  final String description;

  /// 事件重要性（0-100）
  final int importance;

  /// 发生时间（第几天，第几个阶段）
  final String timestamp;

  KeyEvent({
    required this.description,
    required this.importance,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'importance': importance,
      'timestamp': timestamp,
    };
  }

  factory KeyEvent.fromJson(Map<String, dynamic> json) {
    return KeyEvent(
      description: json['description'] as String,
      // 容忍浮点数类型的importance
      importance: json['importance'] is num
          ? (json['importance'] as num).toInt()
          : json['importance'] as int,
      timestamp: json['timestamp'] as String,
    );
  }
}

/// 社交关系网络
class SocialRelationships {
  /// 盟友关系（key: 玩家A, value: 玩家A的盟友列表）
  final Map<String, List<String>> alliances;

  /// 敌对关系（key: 玩家A, value: 玩家A的敌人列表）
  final Map<String, List<String>> hostilities;

  /// 我最信任的玩家（最多3个）
  final List<String> myMostTrusted;

  /// 我最怀疑的玩家（最多3个）
  final List<String> myMostSuspicious;

  SocialRelationships({
    this.alliances = const {},
    this.hostilities = const {},
    this.myMostTrusted = const [],
    this.myMostSuspicious = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'alliances': alliances,
      'hostilities': hostilities,
      'my_most_trusted': myMostTrusted,
      'my_most_suspicious': myMostSuspicious,
    };
  }

  factory SocialRelationships.fromJson(Map<String, dynamic> json) {
    return SocialRelationships(
      alliances: (json['alliances'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as List).cast<String>()),
          ) ??
          {},
      hostilities: (json['hostilities'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as List).cast<String>()),
          ) ??
          {},
      myMostTrusted: (json['my_most_trusted'] as List?)?.cast<String>() ?? [],
      myMostSuspicious:
          (json['my_most_suspicious'] as List?)?.cast<String>() ?? [],
    );
  }
}
