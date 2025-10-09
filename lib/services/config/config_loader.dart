import 'dart:convert';
import 'dart:io' if (dart.library.html) 'package:werewolf_arena/services/config/platform_io_stub.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werewolf_arena/services/config/config.dart';

/// 配置加载策略接口
abstract class ConfigLoader {
  Future<GameConfig> loadGameConfig();
  Future<LLMConfig> loadLLMConfig();
  Future<void> saveGameConfig(GameConfig config);
  Future<void> saveLLMConfig(LLMConfig config);
}

/// Console端配置加载器 - 从二进制所在目录加载YAML文件
class ConsoleConfigLoader implements ConfigLoader {
  final String? customConfigDir;

  ConsoleConfigLoader({this.customConfigDir});

  String get _configDir {
    if (customConfigDir != null) {
      return customConfigDir!;
    }
    // 从当前可执行文件目录加载
    return path.join(Directory.current.path, 'config');
  }

  @override
  Future<GameConfig> loadGameConfig() async {
    try {
      final configPath = path.join(_configDir, 'game_config.yaml');
      return GameConfig.loadFromFile(configPath);
    } catch (e) {
      print('无法从文件加载游戏配置: $e，使用默认配置');
      return GameConfig.defaults();
    }
  }

  @override
  Future<LLMConfig> loadLLMConfig() async {
    try {
      final configPath = path.join(_configDir, 'llm_config.yaml');
      return LLMConfig.loadFromFile(configPath);
    } catch (e) {
      print('无法从文件加载LLM配置: $e，使用默认配置');
      return LLMConfig.defaults();
    }
  }

  @override
  Future<void> saveGameConfig(GameConfig config) async {
    // Console端不保存配置，只从文件读取
    print('Console端不支持保存游戏配置');
  }

  @override
  Future<void> saveLLMConfig(LLMConfig config) async {
    // Console端不保存配置，只从文件读取
    print('Console端不支持保存LLM配置');
  }
}

/// 移动端/GUI端配置加载器 - 从SharedPreferences加载
class PersistentConfigLoader implements ConfigLoader {
  static const String _keyGameConfig = 'game_config';
  static const String _keyLLMConfig = 'llm_config';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<GameConfig> loadGameConfig() async {
    try {
      final prefsInstance = await prefs;
      final jsonStr = prefsInstance.getString(_keyGameConfig);

      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return GameConfig.fromJson(json);
      }
    } catch (e) {
      print('无法从本地存储加载游戏配置: $e');
    }

    // 首次运行或加载失败，使用默认配置并保存
    final defaultConfig = GameConfig.defaults();
    await saveGameConfig(defaultConfig);
    return defaultConfig;
  }

  @override
  Future<LLMConfig> loadLLMConfig() async {
    try {
      final prefsInstance = await prefs;
      final jsonStr = prefsInstance.getString(_keyLLMConfig);

      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return LLMConfig.fromJson(json);
      }
    } catch (e) {
      print('无法从本地存储加载LLM配置: $e');
    }

    // 首次运行或加载失败，使用默认配置并保存
    final defaultConfig = LLMConfig.defaults();
    await saveLLMConfig(defaultConfig);
    return defaultConfig;
  }

  @override
  Future<void> saveGameConfig(GameConfig config) async {
    try {
      final prefsInstance = await prefs;
      final jsonStr = jsonEncode(config.toJson());
      await prefsInstance.setString(_keyGameConfig, jsonStr);
      print('游戏配置已保存到本地存储');
    } catch (e) {
      print('保存游戏配置失败: $e');
    }
  }

  @override
  Future<void> saveLLMConfig(LLMConfig config) async {
    try {
      final prefsInstance = await prefs;
      final jsonStr = jsonEncode(config.toJson());
      await prefsInstance.setString(_keyLLMConfig, jsonStr);
      print('LLM配置已保存到本地存储');
    } catch (e) {
      print('保存LLM配置失败: $e');
    }
  }
}

/// 配置加载器工厂
class ConfigLoaderFactory {
  /// 判断当前是否为Console环境
  static bool get isConsoleEnvironment {
    try {
      // 如果能访问stdout并且不是Flutter应用，则认为是Console环境
      return stdout.hasTerminal;
    } catch (e) {
      return false;
    }
  }

  /// 创建适合当前平台的配置加载器
  static ConfigLoader create({String? customConfigDir, bool? forceConsole}) {
    final useConsole = forceConsole ?? isConsoleEnvironment;

    if (useConsole) {
      return ConsoleConfigLoader(customConfigDir: customConfigDir);
    } else {
      return PersistentConfigLoader();
    }
  }
}
