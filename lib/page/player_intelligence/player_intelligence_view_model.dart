import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:signals/signals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'dart:convert';

import 'package:werewolf_arena/router/router.gr.dart';

class PlayerIntelligenceViewModel {
  // Signals 状态管理 - LLM 配置
  final llmModels = signal(['minimax/minimax-m2:free']);
  final defaultApiKey = signal('');
  final defaultBaseUrl = signal('https://openrouter.ai/api/v1');
  final isLoading = signal(false);
  final showApiKey = signal(false);
  final defaultPlayerIntelligence = signal(
    PlayerIntelligence(
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: '',
      modelId: 'minimax/minimax-m2:free',
    ),
  );

  // SharedPreferences 键名
  static const String _keyLLMModels = 'llm_models';
  static const String _keyLLMApiKey = 'llm_api_key';
  static const String _keyLLMBaseUrl = 'llm_base_url';

  SharedPreferences? _preferences;

  void navigatePlayerIntelligenceDetailPage(
    BuildContext context,
    PlayerIntelligence intelligence,
  ) {
    PlayerIntelligenceDetailRoute(intelligence: intelligence).push(context);
  }

  /// 初始化设置
  Future<void> initSignals() async {
    isLoading.value = true;
    // TODO: load from database
    isLoading.value = false;
  }

  /// 导航回设置页面
  void navigateBack(BuildContext context) {
    context.router.pop();
  }

  /// 添加模型
  Future<void> addModel(String modelId) async {
    final models = List<String>.from(llmModels.value);
    models.add(modelId);
    llmModels.value = models;
    await _saveConfig();
  }

  /// 删除模型
  Future<void> removeModel(int index) async {
    final models = List<String>.from(llmModels.value);
    if (index >= 0 && index < models.length) {
      models.removeAt(index);
      llmModels.value = models;
      await _saveConfig();
    }
  }

  /// 更新模型
  Future<void> updateModel(int index, String modelId) async {
    final models = List<String>.from(llmModels.value);
    if (index >= 0 && index < models.length) {
      models[index] = modelId;
      llmModels.value = models;
      await _saveConfig();
    }
  }

  /// 设置 API Key
  Future<void> setLLMApiKey(String key) async {
    defaultApiKey.value = key;
    await _saveConfig();
  }

  /// 设置 Base URL
  Future<void> setLLMBaseUrl(String url) async {
    defaultBaseUrl.value = url;
    await _saveConfig();
  }

  /// 切换 API Key 显示/隐藏
  void toggleShowApiKey() {
    showApiKey.value = !showApiKey.value;
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    llmModels.value = ['minimax/minimax-m2:free'];
    defaultApiKey.value = '';
    defaultBaseUrl.value = 'https://openrouter.ai/api/v1';
    await _saveConfig();
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();

      final modelsJson = jsonEncode(llmModels.value);
      await _preferences!.setString(_keyLLMModels, modelsJson);
      await _preferences!.setString(_keyLLMApiKey, defaultApiKey.value);
      await _preferences!.setString(_keyLLMBaseUrl, defaultBaseUrl.value);
    } catch (e) {
      // 保存失败
    }
  }

  /// 清理资源
  void dispose() {
    llmModels.dispose();
    defaultApiKey.dispose();
    defaultBaseUrl.dispose();
    isLoading.dispose();
    showApiKey.dispose();
  }
}
