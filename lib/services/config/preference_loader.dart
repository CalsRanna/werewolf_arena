import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werewolf_arena/services/config/config.dart';

/// GUI应用配置加载器 - 从 SharedPreferences 加载和保存配置
/// 用于 Flutter GUI 应用，将配置持久化到本地存储
class PreferenceConfigLoader {
  static const String _keyConfig = 'app_config';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 从 SharedPreferences 加载配置
  Future<AppConfig> loadConfig() async {
    try {
      final prefsInstance = await prefs;
      final jsonStr = prefsInstance.getString(_keyConfig);

      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AppConfig.fromJson(json);
      }
    } catch (e) {
      print('无法从本地存储加载配置: $e');
    }

    // 首次运行或加载失败，使用默认配置并保存
    final defaultConfig = AppConfig.defaults();
    await saveConfig(defaultConfig);
    return defaultConfig;
  }

  /// 保存配置到 SharedPreferences
  Future<void> saveConfig(AppConfig config) async {
    try {
      final prefsInstance = await prefs;
      final jsonStr = jsonEncode(config.toJson());
      await prefsInstance.setString(_keyConfig, jsonStr);
      print('配置已保存到本地存储');
    } catch (e) {
      print('保存配置失败: $e');
    }
  }
}
