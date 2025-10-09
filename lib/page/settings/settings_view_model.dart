import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

class SettingsViewModel {
  // 设置状态
  bool _soundEnabled = true;
  bool _animationsEnabled = true;
  String _selectedTheme = 'dark';
  double _textSpeed = 1.0;

  /// 初始化设置
  Future<void> initSignals() async {
    // TODO: 从shared_preferences加载设置
    _loadSettings();
  }

  /// 导航回主页
  void navigateBack(BuildContext context) {
    context.router.pop();
  }

  /// 切换音效
  void toggleSound(bool value) {
    _soundEnabled = value;
    _saveSettings();
  }

  /// 切换动画
  void toggleAnimations(bool value) {
    _animationsEnabled = value;
    _saveSettings();
  }

  /// 设置主题
  void setTheme(String theme) {
    _selectedTheme = theme;
    _saveSettings();
  }

  /// 设置文字速度
  void setTextSpeed(double speed) {
    _textSpeed = speed;
    _saveSettings();
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
  void resetSettings() {
    _soundEnabled = true;
    _animationsEnabled = true;
    _selectedTheme = 'dark';
    _textSpeed = 1.0;
    _saveSettings();
  }

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get animationsEnabled => _animationsEnabled;
  String get selectedTheme => _selectedTheme;
  double get textSpeed => _textSpeed;

  /// 加载设置
  void _loadSettings() {
    // TODO: 从shared_preferences加载
    // _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    // _animationsEnabled = prefs.getBool('animations_enabled') ?? true;
    // _selectedTheme = prefs.getString('selected_theme') ?? 'dark';
    // _textSpeed = prefs.getDouble('text_speed') ?? 1.0;
  }

  /// 保存设置
  void _saveSettings() {
    // TODO: 保存到shared_preferences
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('sound_enabled', _soundEnabled);
    // await prefs.setBool('animations_enabled', _animationsEnabled);
    // await prefs.setString('selected_theme', _selectedTheme);
    // await prefs.setDouble('text_speed', _textSpeed);
  }
}