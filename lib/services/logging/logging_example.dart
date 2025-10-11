/// 新的简化日志系统使用示例
///
/// 这个文件展示了重构后的日志系统的使用方法

import 'package:werewolf_arena/util/logger_util.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';

/// 日志系统使用示例
class LoggingExample {
  /// 初始化和基本使用
  static Future<void> basicExample() async {
    // 1. 初始化日志系统
    await LoggerUtil.instance.initialize(
      enableConsole: true, // 启用控制台输出
      enableFile: true, // 启用文件输出
      logLevel: 'debug', // 设置日志级别
      logFileName: 'app.log', // 日志文件名
    );

    // 2. 使用不同级别的日志
    LoggerUtil.instance.d('这是一个调试消息');
    LoggerUtil.instance.i('这是一个信息消息');
    LoggerUtil.instance.w('这是一个警告消息');
    LoggerUtil.instance.e('这是一个错误消息', Exception('示例错误'));
    LoggerUtil.instance.f('这是一个致命错误消息');

    // 3. 检查日志文件路径
    print('日志文件路径: ${LoggerUtil.instance.logFilePath}');

    // 4. 清理资源
    await LoggerUtil.instance.dispose();
  }

  /// 玩家日志使用示例
  static Future<void> playerLogExample() async {
    // 注意：这里需要真实的 GamePlayer 和 GameState 对象

    // 为单个玩家记录事件日志
    // await PlayerLogger.instance.logPlayerEvents(player, gameState);

    // 为所有玩家记录事件日志
    // await PlayerLogger.instance.logAllPlayersEvents(gameState);

    // 清理旧的玩家日志文件（7天前的）
    await PlayerLogger.instance.clearOldLogs();

    // 清理资源
    await PlayerLogger.instance.dispose();
  }

  /// 配置不同的日志级别
  static Future<void> logLevelExample() async {
    // 只输出警告和错误
    await LoggerUtil.instance.initialize(logLevel: 'warning');

    LoggerUtil.instance.d('这条消息不会显示'); // 被过滤掉
    LoggerUtil.instance.i('这条消息不会显示'); // 被过滤掉
    LoggerUtil.instance.w('这条消息会显示'); // 会显示
    LoggerUtil.instance.e('这条消息会显示'); // 会显示
  }

  /// 只使用控制台输出（不创建文件）
  static Future<void> consoleOnlyExample() async {
    await LoggerUtil.instance.initialize(
      enableConsole: true,
      enableFile: false,
    );

    LoggerUtil.instance.i('这条消息只会在控制台显示，不会写入文件');
  }

  /// 只使用文件输出（不显示在控制台）
  static Future<void> fileOnlyExample() async {
    await LoggerUtil.instance.initialize(
      enableConsole: false,
      enableFile: true,
      logFileName: 'silent.log',
    );

    LoggerUtil.instance.i('这条消息只会写入文件，不会在控制台显示');
  }
}

/// 主要改进点：
/// 
/// 1. **简化的 API**: 
///    - 不再需要复杂的 LogCategory 参数
///    - 统一的单例访问方式
///    - 简单的方法名称 (d, i, w, e, f)
/// 
/// 2. **灵活的配置**:
///    - 可以独立控制控制台和文件输出
///    - 可配置的日志级别过滤
///    - 自定义日志文件名
/// 
/// 3. **更好的错误处理**:
///    - 文件创建失败时自动降级到控制台输出
///    - 清晰的错误提示
/// 
/// 4. **资源管理**:
///    - 正确的单例模式实现
///    - 资源清理方法
/// 
/// 5. **玩家日志功能**:
///    - 独立的玩家事件日志记录
///    - 自动的旧日志清理
///    - 更清晰的日志格式