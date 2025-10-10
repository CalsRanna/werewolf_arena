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

  // 玩家专属配置 (简化版：只有 model, apiKey, baseUrl)
  final Signal<Map<String, PlayerLLMConfig>> playerConfigs = signal({});

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

      // 构建新的 AppConfig
      final currentConfig = _configService.appConfig;
      final newConfig = AppConfig(
        defaultModel: defaultModel.value,
        defaultApiKey: defaultApiKey.value,
        defaultBaseUrl: defaultBaseUrl.value.isEmpty ? null : defaultBaseUrl.value,
        timeoutSeconds: defaultTimeout.value,
        maxRetries: defaultMaxRetries.value,
        playerModels: playerConfigs.value,
        logging: currentConfig.logging,  // 保留现有日志配置
      );

      // 保存到游戏参数
      await _configService.gameParameters!.saveConfig(newConfig);

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
    final currentConfigs = Map<String, PlayerLLMConfig>.from(playerConfigs.value);
    currentConfigs[playerId] = PlayerLLMConfig(
      model: '',
      apiKey: '',
      baseUrl: null,
    );
    playerConfigs.value = currentConfigs;
  }

  /// 更新玩家配置
  void updatePlayerConfig(String playerId, String field, String value) {
    final currentConfigs = Map<String, PlayerLLMConfig>.from(playerConfigs.value);
    final existing = currentConfigs[playerId];
    if (existing == null) return;

    switch (field) {
      case 'model':
        currentConfigs[playerId] = PlayerLLMConfig(
          model: value,
          apiKey: existing.apiKey,
          baseUrl: existing.baseUrl,
        );
        break;
      case 'apiKey':
        currentConfigs[playerId] = PlayerLLMConfig(
          model: existing.model,
          apiKey: value,
          baseUrl: existing.baseUrl,
        );
        break;
      case 'baseUrl':
        currentConfigs[playerId] = PlayerLLMConfig(
          model: existing.model,
          apiKey: existing.apiKey,
          baseUrl: value.isEmpty ? null : value,
        );
        break;
    }
    playerConfigs.value = currentConfigs;
  }

  /// 删除玩家配置
  void removePlayerConfig(String playerId) {
    final currentConfigs = Map<String, PlayerLLMConfig>.from(playerConfigs.value);
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
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      await _configService.ensureInitialized();
      final appConfig = _configService.appConfig;

      // 加载默认配置
      defaultModel.value = appConfig.defaultModel;
      defaultApiKey.value = appConfig.defaultApiKey;
      defaultBaseUrl.value = appConfig.defaultBaseUrl ?? 'https://api.openai.com/v1';
      defaultTimeout.value = appConfig.timeoutSeconds;
      defaultMaxRetries.value = appConfig.maxRetries;

      // 加载玩家配置
      playerConfigs.value = Map<String, PlayerLLMConfig>.from(appConfig.playerModels);
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
    isLoading.dispose();
  }
}
