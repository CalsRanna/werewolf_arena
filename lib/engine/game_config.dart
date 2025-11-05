/// 推理引擎类型
enum ReasoningEngineType {
  /// 链式推理引擎 - 10步推理链，串行执行（最详细，最慢）
  chain,

  /// 分阶段推理引擎 - 三阶段：预处理 + 核心认知 + 后处理（平衡性能与质量）
  staged,

  /// 直接推理引擎 - 单次LLM调用完成所有推理（最快，最简单）
  direct,
}

/// 游戏配置类
///
/// 提供游戏引擎运行所必需的技术参数
class GameConfig {
  /// 玩家智能配置列表
  final List<PlayerIntelligence> playerIntelligences;

  /// 最大重试次数
  final int maxRetries;

  /// 快速模型ID（用于简单推理任务的性能优化）
  ///
  /// Chain模式：用于不需要复杂推理的步骤（PlaybookSelection, MaskSelection等）
  /// Staged模式：用于预处理和后处理阶段
  /// Direct模式：不使用（所有推理都用主模型）
  ///
  /// 如果为null，所有步骤都使用玩家的主模型
  final String? fastModelId;

  /// 推理引擎类型
  ///
  /// - chain: 10步链式推理（最详细，最慢）
  /// - staged: 3阶段推理（平衡性能和质量）
  /// - direct: 单次LLM调用（最快）
  final ReasoningEngineType reasoningEngineType;

  const GameConfig({
    required this.playerIntelligences,
    required this.maxRetries,
    this.fastModelId,
    this.reasoningEngineType = ReasoningEngineType.staged,
  });

  /// 获取指定玩家的智能配置
  ///
  /// [playerIndex] 玩家索引（从1开始）
  /// 返回对应玩家的智能配置，如果索引无效则返回null
  PlayerIntelligence? getPlayerIntelligence(int playerIndex) {
    if (playerIndex < 1 || playerIndex > playerIntelligences.length) {
      return null;
    }
    return playerIntelligences[playerIndex - 1];
  }

  /// 获取默认智能配置（第一个玩家的配置）
  PlayerIntelligence? get defaultIntelligence =>
      playerIntelligences.isNotEmpty ? playerIntelligences.first : null;

  /// 创建配置副本用于修改
  GameConfig copyWith({
    List<PlayerIntelligence>? playerIntelligences,
    int? maxRetries,
    String? fastModelId,
    ReasoningEngineType? reasoningEngineType,
  }) {
    return GameConfig(
      playerIntelligences: playerIntelligences ?? this.playerIntelligences,
      maxRetries: maxRetries ?? this.maxRetries,
      fastModelId: fastModelId ?? this.fastModelId,
      reasoningEngineType: reasoningEngineType ?? this.reasoningEngineType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameConfig &&
          runtimeType == other.runtimeType &&
          playerIntelligences == other.playerIntelligences &&
          maxRetries == other.maxRetries &&
          fastModelId == other.fastModelId &&
          reasoningEngineType == other.reasoningEngineType;

  @override
  int get hashCode =>
      playerIntelligences.hashCode ^
      maxRetries.hashCode ^
      fastModelId.hashCode ^
      reasoningEngineType.hashCode;

  @override
  String toString() {
    return 'GameConfig{playerIntelligences: $playerIntelligences, maxRetries: $maxRetries, fastModelId: $fastModelId, reasoningEngineType: $reasoningEngineType}';
  }
}

/// 玩家智能配置类
///
/// 包含AI玩家连接到LLM服务所需的配置信息
class PlayerIntelligence {
  /// API基础URL
  final String baseUrl;

  /// API密钥
  final String apiKey;

  /// 模型ID
  final String modelId;

  const PlayerIntelligence({
    required this.baseUrl,
    required this.apiKey,
    required this.modelId,
  });

  factory PlayerIntelligence.fromJson(Map<String, dynamic> json) {
    return PlayerIntelligence(
      baseUrl: json['base_url'],
      apiKey: json['api_key'],
      modelId: json['model_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'base_url': baseUrl, 'api_key': apiKey, 'model_id': modelId};
  }

  /// 创建副本用于修改
  PlayerIntelligence copyWith({
    String? baseUrl,
    String? apiKey,
    String? modelId,
  }) {
    return PlayerIntelligence(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerIntelligence &&
          runtimeType == other.runtimeType &&
          baseUrl == other.baseUrl &&
          apiKey == other.apiKey &&
          modelId == other.modelId;

  @override
  int get hashCode => baseUrl.hashCode ^ apiKey.hashCode ^ modelId.hashCode;

  @override
  String toString() {
    return 'PlayerIntelligence{baseUrl: $baseUrl, apiKey: $apiKey, modelId: $modelId}';
  }
}
