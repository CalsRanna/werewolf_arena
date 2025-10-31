import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:signals/signals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlayerIntelligenceViewModel {
  // Signals 状态管理 - LLM 配置
  final Signal<List<String>> llmModels = signal(['minimax/minimax-m2:free']);
  final Signal<String> defaultApiKey = signal('');
  final Signal<String> defaultBaseUrl = signal('https://openrouter.ai/api/v1');
  final Signal<bool> isLoading = signal(false);
  final Signal<bool> showApiKey = signal(false);

  // SharedPreferences 键名
  static const String _keyLLMModels = 'llm_models';
  static const String _keyLLMApiKey = 'llm_api_key';
  static const String _keyLLMBaseUrl = 'llm_base_url';

  SharedPreferences? _preferences;

  /// 初始化设置
  Future<void> initSignals() async {
    isLoading.value = true;
    await _loadConfig();
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

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      _preferences = await SharedPreferences.getInstance();

      // 从 SharedPreferences 加载配置
      final modelsJson = _preferences?.getString(_keyLLMModels);
      if (modelsJson != null && modelsJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(modelsJson);
        llmModels.value = jsonList.map((e) => e.toString()).toList();
      } else {
        // 使用默认模型
        llmModels.value = ['minimax/minimax-m2:free'];
      }

      defaultApiKey.value = _preferences?.getString(_keyLLMApiKey) ?? '';
      defaultBaseUrl.value =
          _preferences?.getString(_keyLLMBaseUrl) ??
          'https://openrouter.ai/api/v1';
    } catch (e) {
      // 使用默认值
    }
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
