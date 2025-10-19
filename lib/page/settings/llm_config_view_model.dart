import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals.dart';
import 'package:werewolf_arena/services/config/config.dart';

class LLMConfigViewModel {
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
  Future<void> saveConfig(BuildContext context) async {}

  /// 添加玩家配置
  void addPlayerConfig(String playerId) {
    final currentConfigs = Map<String, PlayerLLMConfig>.from(
      playerConfigs.value,
    );
    currentConfigs[playerId] = PlayerLLMConfig(
      model: '',
      apiKey: '',
      baseUrl: null,
    );
    playerConfigs.value = currentConfigs;
  }

  /// 更新玩家配置
  void updatePlayerConfig(String playerId, String field, String value) {
    final currentConfigs = Map<String, PlayerLLMConfig>.from(
      playerConfigs.value,
    );
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
    final currentConfigs = Map<String, PlayerLLMConfig>.from(
      playerConfigs.value,
    );
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
  Future<void> _loadConfig() async {}

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
