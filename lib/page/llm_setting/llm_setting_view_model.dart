import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:signals/signals.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LLMSettingViewModel {
  // Signals 状态管理 - LLM 配置
  final Signal<String> llmModel = signal('minimax/minimax-m2:free');
  final Signal<String> llmApiKey = signal('');
  final Signal<String> llmBaseUrl = signal('https://openrouter.ai/api/v1');
  final Signal<bool> isLoading = signal(false);
  final Signal<bool> showApiKey = signal(false);

  // SharedPreferences 键名
  static const String _keyLLMModel = 'llm_model';
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

  /// 设置 LLM 模型
  Future<void> setLLMModel(String model) async {
    llmModel.value = model;
    await _saveConfig();
  }

  /// 设置 API Key
  Future<void> setLLMApiKey(String key) async {
    llmApiKey.value = key;
    await _saveConfig();
  }

  /// 设置 Base URL
  Future<void> setLLMBaseUrl(String url) async {
    llmBaseUrl.value = url;
    await _saveConfig();
  }

  /// 切换 API Key 显示/隐藏
  void toggleShowApiKey() {
    showApiKey.value = !showApiKey.value;
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    llmModel.value = 'minimax/minimax-m2:free';
    llmApiKey.value = '';
    llmBaseUrl.value = 'https://openrouter.ai/api/v1';
    await _saveConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      _preferences = await SharedPreferences.getInstance();

      // 从 SharedPreferences 加载配置
      llmModel.value =
          _preferences?.getString(_keyLLMModel) ?? 'minimax/minimax-m2:free';
      llmApiKey.value = _preferences?.getString(_keyLLMApiKey) ?? '';
      llmBaseUrl.value =
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

      await _preferences!.setString(_keyLLMModel, llmModel.value);
      await _preferences!.setString(_keyLLMApiKey, llmApiKey.value);
      await _preferences!.setString(_keyLLMBaseUrl, llmBaseUrl.value);
    } catch (e) {
      // 保存失败
    }
  }

  /// 清理资源
  void dispose() {
    llmModel.dispose();
    llmApiKey.dispose();
    llmBaseUrl.dispose();
    isLoading.dispose();
    showApiKey.dispose();
  }
}
