import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/services/config/config.dart';

/// Console端配置加载器 - 从可执行文件所在目录加载 YAML 文件
class ConsoleConfigLoader {
  final String? customConfigDir;

  ConsoleConfigLoader({this.customConfigDir});

  String get _configDir {
    if (customConfigDir != null) {
      return customConfigDir!;
    }
    // 从当前可执行文件目录加载
    return Directory.current.path;
  }

  /// 加载配置文件
  Future<AppConfig> loadConfig() async {
    try {
      final configPath = path.join(_configDir, 'werewolf_config.yaml');
      return AppConfig.loadFromFile(configPath);
    } catch (e) {
      GameEngineLogger.instance.e('无法从文件加载配置: $e，使用默认配置');
      return AppConfig.defaults();
    }
  }

  /// Console端不支持保存配置，只从文件读取
  Future<void> saveConfig(AppConfig config) async {
    GameEngineLogger.instance.w(
      'Console端不支持保存配置，请手动编辑 werewolf_config.yaml 文件',
    );
  }
}
