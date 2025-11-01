import 'package:werewolf_arena/engine/memory/social_network.dart';

/// 工作记忆
///
/// 替代原有的字符串记忆，提供结构化的记忆存储
/// 记录AI玩家的核心认知：身份推测、关键事件、社交关系等
class WorkingMemory {
  /// 玩家的秘密信息（只有该玩家知道）
  final SecretKnowledge secretKnowledge;

  /// 玩家对其他玩家的身份推测
  final Map<String, IdentityEstimate> identityEstimates;

  /// 关键事实列表（按重要性排序）
  final List<KeyFact> keyFacts;

  /// 当前关注的核心矛盾
  String? coreConflict;

  /// 重点关注的玩家（最多3个）
  final List<String> focusPlayers;

  /// 当前采用的策略（如"低调观察"、"强势领袖"等）
  String? currentStrategy;

  /// 社交关系网络
  SocialNetwork? socialNetwork;

  WorkingMemory({
    required this.secretKnowledge,
    Map<String, IdentityEstimate>? identityEstimates,
    List<KeyFact>? keyFacts,
    this.coreConflict,
    List<String>? focusPlayers,
    this.currentStrategy,
    this.socialNetwork,
  })  : identityEstimates = identityEstimates ?? {},
        keyFacts = keyFacts ?? [],
        focusPlayers = focusPlayers ?? [];

  /// 添加关键事实
  void addKeyFact(KeyFact fact) {
    keyFacts.add(fact);
    // 保持列表最多10个事实
    if (keyFacts.length > 10) {
      keyFacts.removeAt(0);
    }
  }

  /// 更新身份推测
  void updateIdentityEstimate(String playerName, IdentityEstimate estimate) {
    identityEstimates[playerName] = estimate;
  }

  /// 设置重点关注玩家
  void setFocusPlayers(List<String> players) {
    focusPlayers.clear();
    focusPlayers.addAll(players.take(3));
  }

  /// 更新社交网络
  void updateSocialNetwork(SocialNetwork network) {
    socialNetwork = network;
  }

  /// 转换为文本格式（用于LLM prompt）
  String toPromptText() {
    final buffer = StringBuffer();

    buffer.writeln('# **我的工作记忆**');
    buffer.writeln();

    // 秘密信息
    buffer.writeln('## 秘密信息（只有我知道）');
    buffer.writeln(secretKnowledge.toText());
    buffer.writeln();

    // 核心矛盾
    if (coreConflict != null && coreConflict!.isNotEmpty) {
      buffer.writeln('## 当前核心矛盾');
      buffer.writeln(coreConflict);
      buffer.writeln();
    }

    // 关键事实
    if (keyFacts.isNotEmpty) {
      buffer.writeln('## 关键事实（按重要性排序）');
      for (var i = 0; i < keyFacts.length; i++) {
        buffer.writeln('${i + 1}. ${keyFacts[i].description}');
      }
      buffer.writeln();
    }

    // 身份推测
    if (identityEstimates.isNotEmpty) {
      buffer.writeln('## 身份推测');
      identityEstimates.forEach((player, estimate) {
        buffer.writeln('- $player: ${estimate.toText()}');
      });
      buffer.writeln();
    }

    // 重点关注玩家
    if (focusPlayers.isNotEmpty) {
      buffer.writeln('## 重点关注玩家');
      buffer.writeln(focusPlayers.join(', '));
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 从JSON创建（用于持久化）
  factory WorkingMemory.fromJson(Map<String, dynamic> json) {
    return WorkingMemory(
      secretKnowledge: SecretKnowledge.fromJson(json['secretKnowledge']),
      identityEstimates: (json['identityEstimates'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, IdentityEstimate.fromJson(v))) ??
          {},
      keyFacts: (json['keyFacts'] as List?)
              ?.map((e) => KeyFact.fromJson(e))
              .toList() ??
          [],
      coreConflict: json['coreConflict'],
      focusPlayers: (json['focusPlayers'] as List?)?.cast<String>() ?? [],
      currentStrategy: json['currentStrategy'],
    );
  }

  /// 转换为JSON（用于持久化）
  Map<String, dynamic> toJson() {
    return {
      'secretKnowledge': secretKnowledge.toJson(),
      'identityEstimates':
          identityEstimates.map((k, v) => MapEntry(k, v.toJson())),
      'keyFacts': keyFacts.map((f) => f.toJson()).toList(),
      'coreConflict': coreConflict,
      'focusPlayers': focusPlayers,
      'currentStrategy': currentStrategy,
    };
  }
}

/// 秘密知识
///
/// 存储只有该玩家知道的信息（如真实身份、队友、夜间行动结果）
class SecretKnowledge {
  /// 玩家的真实角色
  final String myRole;

  /// 队友列表（仅狼人有）
  final List<String> teammates;

  /// 查验结果（预言家）
  final Map<String, String> inspectionResults;

  /// 守护记录（守卫）
  final List<String> protectionHistory;

  /// 其他秘密信息
  final Map<String, dynamic> otherSecrets;

  SecretKnowledge({
    required this.myRole,
    List<String>? teammates,
    Map<String, String>? inspectionResults,
    List<String>? protectionHistory,
    Map<String, dynamic>? otherSecrets,
  })  : teammates = teammates ?? [],
        inspectionResults = inspectionResults ?? {},
        protectionHistory = protectionHistory ?? [],
        otherSecrets = otherSecrets ?? {};

  String toText() {
    final buffer = StringBuffer();
    buffer.writeln('- 我的真实身份：$myRole');

    if (teammates.isNotEmpty) {
      buffer.writeln('- 我的队友：${teammates.join(", ")}');
    }

    if (inspectionResults.isNotEmpty) {
      buffer.writeln('- 查验结果：');
      inspectionResults.forEach((player, result) {
        buffer.writeln('  - $player: $result');
      });
    }

    if (protectionHistory.isNotEmpty) {
      buffer.writeln('- 守护历史：${protectionHistory.join(", ")}');
    }

    return buffer.toString();
  }

  factory SecretKnowledge.fromJson(Map<String, dynamic> json) {
    return SecretKnowledge(
      myRole: json['myRole'],
      teammates: (json['teammates'] as List?)?.cast<String>() ?? [],
      inspectionResults:
          (json['inspectionResults'] as Map<String, dynamic>?)?.cast() ?? {},
      protectionHistory:
          (json['protectionHistory'] as List?)?.cast<String>() ?? [],
      otherSecrets: json['otherSecrets'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'myRole': myRole,
      'teammates': teammates,
      'inspectionResults': inspectionResults,
      'protectionHistory': protectionHistory,
      'otherSecrets': otherSecrets,
    };
  }
}

/// 身份推测
///
/// 对某个玩家的身份判断（好人/狼人/神职）及置信度
class IdentityEstimate {
  /// 推测的身份（如"狼人"、"预言家"、"平民"）
  final String estimatedRole;

  /// 置信度 (0-100)
  final int confidence;

  /// 推理依据
  final String reasoning;

  IdentityEstimate({
    required this.estimatedRole,
    required this.confidence,
    required this.reasoning,
  });

  String toText() {
    return '$estimatedRole (置信度: $confidence%) - $reasoning';
  }

  factory IdentityEstimate.fromJson(Map<String, dynamic> json) {
    return IdentityEstimate(
      estimatedRole: json['estimatedRole'],
      confidence: json['confidence'],
      reasoning: json['reasoning'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimatedRole': estimatedRole,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }
}

/// 关键事实
///
/// 记录的重要事件或信息
class KeyFact {
  /// 事实描述
  final String description;

  /// 重要性 (0-100)
  final int importance;

  /// 时间戳（第几天）
  final int day;

  KeyFact({
    required this.description,
    required this.importance,
    required this.day,
  });

  factory KeyFact.fromJson(Map<String, dynamic> json) {
    return KeyFact(
      description: json['description'],
      importance: json['importance'],
      day: json['day'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'importance': importance,
      'day': day,
    };
  }
}
