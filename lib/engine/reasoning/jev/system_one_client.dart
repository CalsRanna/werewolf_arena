import 'dart:convert';
import 'dart:io';

/// Jev / System One 的单条答案。
///
/// 三种原语：noul（是/否概率）、choice（从预定义选项里选一个）、score。
class SystemOneAnswer {
  const SystemOneAnswer({
    required this.type,
    this.noul,
    this.choice,
    this.probabilities = const {},
  });

  final String type;

  /// noul 原语的输出：0-1 的概率
  final double? noul;

  /// choice 原语选中的选项键
  final String? choice;

  /// choice 原语各选项的概率
  final Map<String, double> probabilities;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (noul != null) 'noul': noul,
    if (choice != null) 'choice': choice,
    if (probabilities.isNotEmpty) 'probabilities': probabilities,
  };

  static SystemOneAnswer fromJson(Map<String, dynamic> json) {
    final raw = json['probabilities'];
    return SystemOneAnswer(
      type: json['type'] as String? ?? 'unknown',
      noul: (json['noul'] as num?)?.toDouble(),
      choice: json['choice'] as String?,
      probabilities: raw is Map
          ? {
              for (final entry in raw.entries)
                entry.key.toString(): (entry.value as num).toDouble(),
            }
          : const {},
    );
  }
}

/// 一次 System One 调用的完整结果。
class SystemOneResult {
  const SystemOneResult({
    required this.answers,
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
    required this.model,
  });

  final Map<String, SystemOneAnswer> answers;
  final int inputTokens;
  final int outputTokens;

  /// 上游直接回报的费用（OpenRouter 的 usage.cost）
  final double cost;

  /// 实际服务的版本化模型 id
  final String model;
}

/// Jev 接入设置。默认指向 OpenRouter 的 System One 接口。
class JevSettings {
  const JevSettings({
    this.enabled = true,
    this.baseUrl = 'https://openrouter.ai/api',
    this.model = 'typesafe/jev-1.13',
    this.timeout = const Duration(seconds: 60),
  });

  final bool enabled;

  /// 注意：System One 与 chat completions 是两条接口。OpenRouter 上是
  /// `https://openrouter.ai/api`（SDK 会拼 /v1/systemone）；直连 TypeSafe
  /// 则是 `https://api.typesafe.ai`。
  final String baseUrl;

  final String model;
  final Duration timeout;
}

/// 极简 System One 客户端。
///
/// 不用 OpenAI 兼容客户端：Jev 是 decisions 模态，走 /v1/systemone，
/// 请求体是 {model, state, questions}，塞不进 chat completions。
class SystemOneClient {
  SystemOneClient({
    required this.apiKey,
    this.settings = const JevSettings(),
  });

  final String apiKey;
  final JevSettings settings;

  Future<SystemOneResult> evaluate({
    required String state,
    required Map<String, Object?> questions,
  }) async {
    final body = jsonEncode({
      'model': settings.model,
      'state': state,
      'questions': questions,
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('${settings.baseUrl}/v1/systemone'),
      );
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.contentType = ContentType.json;
      final bytes = utf8.encode(body);
      // 先声明长度再写 body，否则退化成 chunked 传输
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(settings.timeout);
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'System One HTTP ${response.statusCode}: '
          '${text.substring(0, text.length.clamp(0, 300))}',
        );
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final usage = json['usage'] as Map?;
      final rawAnswers = (json['answers'] as Map?) ?? const {};
      return SystemOneResult(
        answers: {
          for (final entry in rawAnswers.entries)
            entry.key.toString(): SystemOneAnswer.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
        },
        inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
        cost: (usage?['cost'] as num?)?.toDouble() ?? 0,
        model: json['model'] as String? ?? settings.model,
      );
    } finally {
      client.close();
    }
  }
}
