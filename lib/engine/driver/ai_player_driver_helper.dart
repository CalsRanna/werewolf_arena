import 'dart:convert';

/// Enhanced JSON cleaner for LLM responses
/// Handles various formats and edge cases from different models
class AIPlayerDriverHelper {
  /// Extract and decode a JSON object from LLM response content.
  ///
  /// Handles markdown formatting, code blocks, and other formatting issues.
  /// Throws [FormatException] if a JSON object cannot be extracted.
  static Map<String, dynamic> extractEmbeddedJson(String content) {
    String cleaned = content;

    // 1. Remove markdown code blocks with language specifiers
    cleaned = cleaned.replaceAll(
      RegExp(r'```(?:json|javascript|js)?\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s*```'), '');

    // 2. Simplified prefix removal - just look for JSON object start
    final jsonStart = cleaned.indexOf('{');
    if (jsonStart > 0) {
      cleaned = cleaned.substring(jsonStart);
    }

    // 3. Remove explanatory text after JSON
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonEnd != -1) {
      final afterJson = cleaned.substring(jsonEnd + 1);
      // Keep only if it's empty or just whitespace
      if (afterJson.trim().isNotEmpty) {
        cleaned = cleaned.substring(0, jsonEnd + 1);
      }
    }

    // 4. Extract JSON object from mixed content
    final jsonStartFinal = cleaned.indexOf('{');
    final jsonEndFinal = cleaned.lastIndexOf('}');

    if (jsonStartFinal != -1 &&
        jsonEndFinal != -1 &&
        jsonEndFinal > jsonStartFinal) {
      cleaned = cleaned.substring(jsonStartFinal, jsonEndFinal + 1);
    }

    // 5. Remove any leading/trailing whitespace
    cleaned = cleaned.trim();

    // 6. Fix common JSON formatting issues
    cleaned = _fixCommonJsonIssues(cleaned);

    if (cleaned.isEmpty) {
      throw const FormatException('No parsable JSON object found');
    }

    return _decode(cleaned);
  }

  /// Attempt to extract valid JSON from malformed response
  static Map<String, dynamic> extractPartialJson(String content) {
    // Try multiple extraction strategies

    // Strategy 1: Standard extraction
    try {
      return extractEmbeddedJson(content);
    } catch (_) {
      // Continue with other strategies
    }

    // Strategy 2: Find JSON-like structures in the content
    final jsonPattern = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}');
    final matches = jsonPattern.allMatches(content);

    for (final match in matches) {
      final candidate = match.group(0)!;
      try {
        final cleanedCandidate = _fixCommonJsonIssues(candidate.trim());
        return _decode(cleanedCandidate);
      } catch (_) {
        // Continue checking other candidates
      }
    }

    // Strategy 3: Fallback extraction using regex
    final manual = _extractFieldsManually(content);
    if (manual != null && manual.isNotEmpty) {
      return manual;
    }

    throw const FormatException('Unable to extract JSON object from content');
  }

  static Map<String, dynamic> _decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      throw FormatException('Failed to decode JSON: ${e.toString()}');
    }

    throw const FormatException('Decoded result is not a JSON object');
  }

  /// Manual field extraction as last resort
  static Map<String, dynamic>? _extractFieldsManually(String content) {
    final result = <String, dynamic>{};

    // Extract action
    final actionMatch = RegExp(
      r'"action"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(content);
    if (actionMatch != null) {
      result['action'] = actionMatch.group(1);
    }

    // Extract target
    final targetMatch = RegExp(
      r'"target"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(content);
    if (targetMatch != null) {
      result['target'] = targetMatch.group(1);
    }

    // Extract reasoning
    final reasoningMatch = RegExp(
      r'"reasoning"\s*:\s*"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(content);
    if (reasoningMatch != null) {
      result['reasoning'] = reasoningMatch.group(1);
    }

    // Extract statement
    final statementMatch = RegExp(
      r'"statement"\s*:\s*"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(content);
    if (statementMatch != null) {
      result['statement'] = statementMatch.group(1);
    }

    return result.isNotEmpty ? result : null;
  }

  /// Fix common JSON formatting issues from LLM responses
  static String _fixCommonJsonIssues(String json) {
    // Don't modify newlines - they should be part of JSON strings properly escaped
    // Fix trailing commas (common in LLM responses)
    json = json.replaceAll(RegExp(r',\s*}'), r'}');
    json = json.replaceAll(RegExp(r',\s*\]'), r']');

    // Fix missing quotes around string values
    json = json.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z_][a-zA-Z0-9_]*)(?=\s*[,}])'),
      (match) => ': "${match.group(1)}"',
    );

    return json;
  }
}
