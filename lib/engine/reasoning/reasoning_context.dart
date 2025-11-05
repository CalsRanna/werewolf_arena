import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 推理上下文
///
/// 在推理过程中传递数据，支持三种推理引擎：
/// - Chain: 在推理链的各个步骤之间传递数据
/// - Staged: 在预处理、核心认知、后处理三个阶段之间传递数据
/// - Direct: 存储单次推理的输入输出
class ReasoningContext {
  /// 当前玩家
  final GamePlayer player;

  /// 当前游戏状态
  final GameContext state;

  /// 当前技能
  final GameSkill skill;

  /// 步骤输出存储
  /// key: 步骤名称, value: 步骤输出
  final Map<String, dynamic> stepOutputs = {};

  /// 元数据：用于调试和日志
  final Map<String, dynamic> metadata = {};

  /// 完整的思考链（拼接所有步骤的reasoning）
  final StringBuffer completeThoughtChain = StringBuffer();

  /// 结构化的世界状态（用于Staged引擎的预处理输出）
  WorldState? worldState;

  ReasoningContext({
    required this.player,
    required this.state,
    required this.skill,
    this.worldState,
  });

  /// 设置步骤输出
  void setStepOutput(String stepName, dynamic output) {
    stepOutputs[stepName] = output;
    metadata['${stepName}_timestamp'] = DateTime.now().toIso8601String();
  }

  /// 记录步骤的token使用量
  void recordStepTokens(String stepName, int tokens) {
    metadata['${stepName}_tokens'] = tokens;

    // 累计总token
    final currentTotal = metadata['total_tokens'] as int? ?? 0;
    metadata['total_tokens'] = currentTotal + tokens;
  }

  /// 获取步骤输出
  T? getStepOutput<T>(String stepName) {
    return stepOutputs[stepName] as T?;
  }

  /// 追加思考内容
  void appendThought(String thought) {
    if (completeThoughtChain.isNotEmpty) {
      completeThoughtChain.write('\n\n');
    }
    completeThoughtChain.write(thought);
  }

  /// 设置元数据
  void setMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  /// 获取元数据
  T? getMetadata<T>(String key) {
    return metadata[key] as T?;
  }

  // ========== 便捷访问器（用于常用的步骤输出）==========

  /// 过滤后的上下文
  dynamic get filteredContext => getStepOutput('information_filter');

  /// 关键事实列表
  List<String>? get keyFacts => getStepOutput<List<String>>('fact_analysis');

  /// 身份推理结果
  Map<String, dynamic>? get identityInference =>
      getStepOutput<Map<String, dynamic>>('identity_inference');

  /// 策略规划结果
  Map<String, dynamic>? get strategy =>
      getStepOutput<Map<String, dynamic>>('strategy');

  /// 战术指令（新增 v2.0）
  Map<String, dynamic>? get tacticalDirective =>
      getStepOutput<Map<String, dynamic>>('tactical_directive');

  /// 选择的战术剧本
  dynamic get selectedPlaybook => getStepOutput('selected_playbook');

  /// 选择的角色面具
  dynamic get selectedMask => getStepOutput('selected_mask');

  /// 行动计划（已废弃，使用 strategy 代替）
  @Deprecated('Use strategy instead')
  dynamic get actionPlan => getStepOutput('strategy_planning');

  /// 最终发言
  String? get finalSpeech => getStepOutput<String>('speech_generation');

  /// 目标玩家
  String? get targetPlayer => getStepOutput<String>('target_player');

  /// 行动预演结果（新增 v2.0）
  Map<String, dynamic>? get actionRehearsalResult =>
      getStepOutput<Map<String, dynamic>>('action_rehearsal_result');

  /// 发言质量评估（自我反思）
  dynamic get qualityAssessment => getStepOutput('self_reflection_result');

  /// 是否需要重新生成（新增 v2.0）
  bool get needsRegeneration =>
      getStepOutput<bool>('needs_regeneration') ?? false;
}

/// 世界状态
///
/// 结构化的游戏状态，用于Staged引擎的预处理输出
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
