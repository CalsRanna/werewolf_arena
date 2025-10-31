class PlayerIntelligenceEntity {
  int id = 0;
  String baseUrl = '';
  String apiKey = '';
  String modelId = '';

  PlayerIntelligenceEntity();

  factory PlayerIntelligenceEntity.fromJson(Map<String, dynamic> json) {
    return PlayerIntelligenceEntity()
      ..id = json['id']
      ..baseUrl = json['base_url']
      ..apiKey = json['api_key']
      ..modelId = json['model_id'];
  }

  PlayerIntelligenceEntity copyWith({
    int? id,
    String? baseUrl,
    String? apiKey,
    String? modelId,
  }) {
    return PlayerIntelligenceEntity()
      ..id = id ?? this.id
      ..baseUrl = baseUrl ?? this.baseUrl
      ..apiKey = apiKey ?? this.apiKey
      ..modelId = modelId ?? this.modelId;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model_id': modelId,
    };
  }
}
