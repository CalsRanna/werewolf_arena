/// 玩家模型配置
class PlayerModelConfig {
  /// 模型名称
  final String model;

  /// API密钥
  final String apiKey;

  /// API基础URL
  final String? baseUrl;

  /// 超时时间(秒)
  final int timeoutSeconds;

  /// 最大重试次数
  final int maxRetries;

  const PlayerModelConfig({
    required this.model,
    required this.apiKey,
    this.baseUrl,
    this.timeoutSeconds = 30,
    this.maxRetries = 3,
  });

  /// 创建副本并更新指定值
  PlayerModelConfig copyWith({
    String? model,
    String? apiKey,
    String? baseUrl,
    int? timeoutSeconds,
    int? maxRetries,
  }) {
    return PlayerModelConfig(
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  /// 从Map创建配置
  factory PlayerModelConfig.fromMap(Map<String, dynamic> map) {
    return PlayerModelConfig(
      model: map['model'] ?? map['model'] ?? 'gpt-3.5-turbo',
      apiKey: map['api_key'] ?? map['apiKey'] ?? '',
      baseUrl: map['base_url'] ?? map['baseUrl'],
      timeoutSeconds: map['timeout_seconds'] ?? map['timeoutSeconds'] ?? 30,
      maxRetries: map['max_retries'] ?? map['maxRetries'] ?? 3,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'api_key': apiKey,
      if (baseUrl != null) 'base_url': baseUrl,
      'timeout_seconds': timeoutSeconds,
      'max_retries': maxRetries,
    };
  }

  @override
  String toString() {
    return 'PlayerModelConfig(model: $model)';
  }
}
