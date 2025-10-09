import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';
import 'package:werewolf_arena/services/config_service.dart';
import 'package:werewolf_arena/services/config/config.dart';

class LLMConfigViewModel {
  final ConfigService _configService = GetIt.instance.get<ConfigService>();

  // 默认配置 Signals
  final Signal<String> defaultModel = signal('gpt-3.5-turbo');
  final Signal<String> defaultApiKey = signal('');
  final Signal<String> defaultBaseUrl = signal('https://api.openai.com/v1');
  final Signal<int> defaultTimeout = signal(30);
  final Signal<int> defaultMaxRetries = signal(3);

  // 玩家专属配置
  final Signal<Map<String, Map<String, dynamic>>> playerConfigs = signal({});

  // 提示词设置
  final Signal<bool> enableContext = signal(true);
  final Signal<bool> strategyHints = signal(true);
  final Signal<bool> personalityTraits = signal(true);
  final Signal<String> baseSystemPrompt = signal('');

  // LLM 高级设置
  final Signal<double> temperature = signal(0.7);
  final Signal<int> maxTokens = signal(1000);
  final Signal<double> topP = signal(0.9);
  final Signal<double> frequencyPenalty = signal(0.0);
  final Signal<double> presencePenalty = signal(0.0);

  // UI 状态
  final Signal<bool> isLoading = signal(false);

  /// 初始化
  Future<void> initSignals() async {
    isLoading.value = true;
    await _loadConfig();
    isLoading.value = false;
  }

  /// 导航回上一页
  void navigateBack(BuildContext context) {
    context.router.pop();
  }

  /// 保存配置
  Future<void> saveConfig(BuildContext context) async {
    try {
      isLoading.value = true;

      // 构建 LLM 配置对象
      final llmConfig = LLMConfig(
        model: defaultModel.value,
        apiKey: defaultApiKey.value,
        baseUrl: defaultBaseUrl.value.isEmpty ? null : defaultBaseUrl.value,
        timeoutSeconds: defaultTimeout.value,
        maxRetries: defaultMaxRetries.value,
        prompts: PromptSettings(
          enableContext: enableContext.value,
          strategyHints: strategyHints.value,
          personalityTraits: personalityTraits.value,
          baseSystemPrompt: baseSystemPrompt.value,
        ),
        llmSettings: {
          'temperature': temperature.value,
          'max_tokens': maxTokens.value,
          'top_p': topP.value,
          'frequency_penalty': frequencyPenalty.value,
          'presence_penalty': presencePenalty.value,
        },
        playerModels: Map<String, Map<String, dynamic>>.from(
          playerConfigs.value.map((key, value) {
            // 只保存非空字段
            final filteredValue = Map<String, dynamic>.from(value)
              ..removeWhere((k, v) => v == null || v == '');
            return MapEntry(key, filteredValue);
          }),
        ),
      );

      // 保存到配置管理器
      await _configService.configManager!.saveLLMConfig(llmConfig);

      isLoading.value = false;

      // 显示成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      isLoading.value = false;

      // 显示错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 添加玩家配置
  void addPlayerConfig(String playerId) {
    final currentConfigs = Map<String, Map<String, dynamic>>.from(playerConfigs.value);
    currentConfigs[playerId] = {};
    playerConfigs.value = currentConfigs;
  }

  /// 更新玩家配置
  void updatePlayerConfig(String playerId, Map<String, dynamic> config) {
    final currentConfigs = Map<String, Map<String, dynamic>>.from(playerConfigs.value);
    currentConfigs[playerId] = config;
    playerConfigs.value = currentConfigs;
  }

  /// 删除玩家配置
  void removePlayerConfig(String playerId) {
    final currentConfigs = Map<String, Map<String, dynamic>>.from(playerConfigs.value);
    currentConfigs.remove(playerId);
    playerConfigs.value = currentConfigs;
  }

  /// 重置为默认配置
  void resetToDefaults() {
    defaultModel.value = 'gpt-3.5-turbo';
    defaultApiKey.value = '';
    defaultBaseUrl.value = 'https://api.openai.com/v1';
    defaultTimeout.value = 30;
    defaultMaxRetries.value = 3;

    playerConfigs.value = {};

    enableContext.value = true;
    strategyHints.value = true;
    personalityTraits.value = true;
    baseSystemPrompt.value = '';

    temperature.value = 0.7;
    maxTokens.value = 1000;
    topP.value = 0.9;
    frequencyPenalty.value = 0.0;
    presencePenalty.value = 0.0;
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      await _configService.ensureInitialized();
      final llmConfig = _configService.llmConfig;

      // 加载默认配置
      defaultModel.value = llmConfig.model;
      defaultApiKey.value = llmConfig.apiKey;
      defaultBaseUrl.value = llmConfig.baseUrl ?? 'https://api.openai.com/v1';
      defaultTimeout.value = llmConfig.timeoutSeconds;
      defaultMaxRetries.value = llmConfig.maxRetries;

      // 加载玩家配置
      playerConfigs.value = Map<String, Map<String, dynamic>>.from(
        llmConfig.playerModels,
      );

      // 加载提示词设置
      enableContext.value = llmConfig.prompts.enableContext;
      strategyHints.value = llmConfig.prompts.strategyHints;
      personalityTraits.value = llmConfig.prompts.personalityTraits;
      baseSystemPrompt.value = llmConfig.prompts.baseSystemPrompt;

      // 加载高级设置
      temperature.value = llmConfig.llmSettings['temperature'] ?? 0.7;
      maxTokens.value = llmConfig.llmSettings['max_tokens'] ?? 1000;
      topP.value = llmConfig.llmSettings['top_p'] ?? 0.9;
      frequencyPenalty.value = llmConfig.llmSettings['frequency_penalty'] ?? 0.0;
      presencePenalty.value = llmConfig.llmSettings['presence_penalty'] ?? 0.0;
    } catch (e) {
      print('加载 LLM 配置失败: $e');
      // 使用默认值
    }
  }

  /// 清理资源
  void dispose() {
    defaultModel.dispose();
    defaultApiKey.dispose();
    defaultBaseUrl.dispose();
    defaultTimeout.dispose();
    defaultMaxRetries.dispose();
    playerConfigs.dispose();
    enableContext.dispose();
    strategyHints.dispose();
    personalityTraits.dispose();
    baseSystemPrompt.dispose();
    temperature.dispose();
    maxTokens.dispose();
    topP.dispose();
    frequencyPenalty.dispose();
    presencePenalty.dispose();
    isLoading.dispose();
  }
}
