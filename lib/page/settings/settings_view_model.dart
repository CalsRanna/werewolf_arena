import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:signals/signals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class SettingsViewModel {
  // Signals 状态管理 - UI设置
  final Signal<bool> soundEnabled = signal(true);
  final Signal<bool> animationsEnabled = signal(true);
  final Signal<String> selectedTheme = signal('dark');
  final Signal<double> textSpeed = signal(1.0);
  final Signal<bool> isLoading = signal(false);

  // Signals 状态管理 - LLM 配置
  final Signal<String> logLevel = signal('info');
  final Signal<String> defaultLLMModel = signal('gpt-3.5-turbo');
  final Signal<String> llmApiKey = signal('');
  final Signal<String> llmBaseUrl = signal('');

  // SharedPreferences 键名 - UI设置
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyAnimationsEnabled = 'animations_enabled';
  static const String _keySelectedTheme = 'selected_theme';
  static const String _keyTextSpeed = 'text_speed';

  SharedPreferences? _prefs;

  /// 初始化设置
  Future<void> initSignals() async {
    isLoading.value = true;
    await _loadSettings();
    await _loadGameConfig();
    isLoading.value = false;
  }

  /// 导航回主页
  void navigateBack(BuildContext context) {
    context.router.pop();
  }

  /// 导航到 LLM 配置页面
  void navigateToLLMConfig(BuildContext context) {
    LLMConfigRoute().push(context);
  }

  /// 切换音效
  Future<void> toggleSound(bool value) async {
    soundEnabled.value = value;
    await _saveSettings();
  }

  /// 切换动画
  Future<void> toggleAnimations(bool value) async {
    animationsEnabled.value = value;
    await _saveSettings();
  }

  /// 设置主题
  Future<void> setTheme(String theme) async {
    selectedTheme.value = theme;
    await _saveSettings();
  }

  /// 设置文字速度
  Future<void> setTextSpeed(double speed) async {
    textSpeed.value = speed;
    await _saveSettings();
  }

  /// 显示关于对话框
  void showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '狼人杀竞技场',
      applicationVersion: '2.0.0',
      applicationIcon: Icon(Icons.casino, size: 48),
      children: [
        Text('基于Flutter架构的AI狼人杀游戏'),
        SizedBox(height: 16),
        Text('特性：'),
        Text('• AI玩家对战'),
        Text('• 实时游戏观察'),
        Text('• 多种角色配置'),
        Text('• 游戏历史记录'),
      ],
    );
  }

  /// 显示许可证对话框
  void showLicenseDialog(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: '狼人杀竞技场',
      applicationVersion: '2.0.0',
    );
  }

  /// 重置设置
  Future<void> resetSettings() async {
    // UI设置
    soundEnabled.value = true;
    animationsEnabled.value = true;
    selectedTheme.value = 'dark';
    textSpeed.value = 1.0;

    // LLM 配置
    logLevel.value = 'info';

    await _saveSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // 从 SharedPreferences 加载设置
      soundEnabled.value = _prefs?.getBool(_keySoundEnabled) ?? true;
      animationsEnabled.value = _prefs?.getBool(_keyAnimationsEnabled) ?? true;
      selectedTheme.value = _prefs?.getString(_keySelectedTheme) ?? 'dark';
      textSpeed.value = _prefs?.getDouble(_keyTextSpeed) ?? 1.0;
    } catch (e) {
      print('加载设置失败: $e');
      // 使用默认值
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      await _prefs!.setBool(_keySoundEnabled, soundEnabled.value);
      await _prefs!.setBool(_keyAnimationsEnabled, animationsEnabled.value);
      await _prefs!.setString(_keySelectedTheme, selectedTheme.value);
      await _prefs!.setDouble(_keyTextSpeed, textSpeed.value);
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  /// 加载游戏配置
  Future<void> _loadGameConfig() async {}

  /// 保存游戏配置
  Future<void> _saveGameConfig() async {}

  /// 设置日志级别
  Future<void> setLogLevel(String level) async {
    logLevel.value = level;
    await _saveGameConfig();
  }

  /// 设置LLM API Key
  Future<void> setLLMApiKey(String key) async {
    llmApiKey.value = key;
    await _saveGameConfig();
  }

  /// 设置LLM Base URL
  Future<void> setLLMBaseUrl(String url) async {
    llmBaseUrl.value = url;
    await _saveGameConfig();
  }

  /// 清理资源
  void dispose() {
    soundEnabled.dispose();
    animationsEnabled.dispose();
    selectedTheme.dispose();
    textSpeed.dispose();
    isLoading.dispose();
    logLevel.dispose();
    defaultLLMModel.dispose();
    llmApiKey.dispose();
    llmBaseUrl.dispose();
  }
}
