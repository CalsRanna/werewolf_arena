import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:werewolf_arena/database/player_intelligence_repository.dart';
import 'package:werewolf_arena/entity/player_intelligence_entity.dart';
import 'package:werewolf_arena/router/router.gr.dart';
import 'package:werewolf_arena/util/dialog_util.dart';

class PlayerIntelligenceViewModel {
  // SharedPreferences 键名
  static const String _keyLLMModels = 'llm_models';
  static const String _keyLLMApiKey = 'llm_api_key';
  static const String _keyLLMBaseUrl = 'llm_base_url';
  // Signals 状态管理 - LLM 配置
  final llmModels = signal(['minimax/minimax-m2:free']);
  final defaultApiKey = signal('');
  final defaultBaseUrl = signal('https://openrouter.ai/api/v1');
  final isLoading = signal(false);

  final showApiKey = signal(false);
  final defaultPlayerIntelligence = signal(
    PlayerIntelligenceEntity()
      ..baseUrl = 'https://openrouter.ai/api/v1'
      ..apiKey = ''
      ..modelId = 'minimax/minimax-m2:free',
  );
  final playerIntelligences = signal(<PlayerIntelligenceEntity>[]);

  SharedPreferences? _preferences;

  /// 添加模型
  Future<void> addModel(String modelId) async {
    final models = List<String>.from(llmModels.value);
    models.add(modelId);
    llmModels.value = models;
    await _saveConfig();
  }

  void createPlayerIntelligence(BuildContext context) {
    var intelligence = PlayerIntelligenceEntity();
    PlayerIntelligenceDetailRoute(intelligence: intelligence).push(context);
  }

  /// 清理资源
  void dispose() {
    llmModels.dispose();
    defaultApiKey.dispose();
    defaultBaseUrl.dispose();
    isLoading.dispose();
    showApiKey.dispose();
  }

  /// 初始化设置
  Future<void> initSignals() async {
    isLoading.value = true;
    final repository = PlayerIntelligenceRepository();
    playerIntelligences.value = await repository.getPlayerIntelligences();
    if (playerIntelligences.value.isEmpty) {
      await repository.storePlayerIntelligence(defaultPlayerIntelligence.value);
      playerIntelligences.value = await repository.getPlayerIntelligences();
    }
    defaultPlayerIntelligence.value = playerIntelligences.value.first;
    playerIntelligences.value = playerIntelligences.value.sublist(1);
    isLoading.value = false;
  }

  /// 导航回设置页面
  void navigateBack(BuildContext context) {
    context.router.pop();
  }

  void navigatePlayerIntelligenceDetailPage(
    BuildContext context,
    PlayerIntelligenceEntity intelligence,
  ) {
    PlayerIntelligenceDetailRoute(intelligence: intelligence).push(context);
  }

  Future<void> refreshPlayerIntelligences() async {
    final repository = PlayerIntelligenceRepository();
    playerIntelligences.value = await repository.getPlayerIntelligences();
    defaultPlayerIntelligence.value = playerIntelligences.value.first;
    playerIntelligences.value = playerIntelligences.value.sublist(1);
  }

  Future<void> destroyPlayerIntelligence(int id) async {
    final result = await DialogUtil.instance.confirm(
      'Do you want to delete this player intelligence?',
    );
    if (!result) return;
    final repository = PlayerIntelligenceRepository();
    await repository.destroyPlayerIntelligence(id);
    await refreshPlayerIntelligences();
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

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    llmModels.value = ['minimax/minimax-m2:free'];
    defaultApiKey.value = '';
    defaultBaseUrl.value = 'https://openrouter.ai/api/v1';
    await _saveConfig();
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

  /// 更新模型
  Future<void> updateModel(int index, String modelId) async {
    final models = List<String>.from(llmModels.value);
    if (index >= 0 && index < models.length) {
      models[index] = modelId;
      llmModels.value = models;
      await _saveConfig();
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
}
