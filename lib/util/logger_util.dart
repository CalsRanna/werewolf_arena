import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

/// 简化的日志系统 - 单例模式，支持控制台和文件输出
class LoggerUtil {
  static LoggerUtil? _instance;
  Logger? _logger;
  String? _logFilePath;

  LoggerUtil._internal();

  /// 获取单例实例
  static LoggerUtil get instance {
    _instance ??= LoggerUtil._internal();
    return _instance!;
  }

  /// 初始化日志系统
  /// 
  /// [enableConsole] 是否启用控制台输出
  /// [enableFile] 是否启用文件输出
  /// [logLevel] 日志级别 (trace, debug, info, warning, error)
  /// [logFileName] 日志文件名，默认为 'app.log'
  Future<void> initialize({
    bool enableConsole = true,
    bool enableFile = true,
    String logLevel = 'info',
    String logFileName = 'app.log',
  }) async {
    final outputs = <LogOutput>[];

    // 控制台输出
    if (enableConsole) {
      outputs.add(ConsoleOutput());
    }

    // 文件输出
    if (enableFile) {
      try {
        // 创建日志目录
        final logsDir = Directory('logs');
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }

        // 设置日志文件路径
        _logFilePath = path.join('logs', logFileName);
        outputs.add(FileOutput(file: File(_logFilePath!)));
      } catch (e) {
        if (enableConsole) {
          print('警告：无法创建文件日志，仅使用控制台输出: $e');
        }
      }
    }

    // 创建 Logger 实例
    _logger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        stackTraceBeginIndex: 0,
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: enableConsole,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput(outputs),
      level: _parseLevel(logLevel),
    );

    // 设置全局日志级别
    Logger.level = _parseLevel(logLevel);
  }

  /// 调试日志
  void d(String message) {
    _logger?.d(message);
  }

  /// 信息日志
  void i(String message) {
    _logger?.i(message);
  }

  /// 警告日志
  void w(String message) {
    _logger?.w(message);
  }

  /// 错误日志
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  /// 致命错误日志
  void f(String message, [Object? error, StackTrace? stackTrace]) {
    _logger?.f(message, error: error, stackTrace: stackTrace);
  }

  /// 跟踪日志
  void t(String message) {
    _logger?.t(message);
  }

  /// 获取当前日志文件路径
  String? get logFilePath => _logFilePath;

  /// 清理资源
  Future<void> dispose() async {
    _logger?.close();
    _logger = null;
    _instance = null;
  }

  /// 解析日志级别
  Level _parseLevel(String level) {
    switch (level.toLowerCase()) {
      case 'trace':
        return Level.trace;
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
      case 'warn':
        return Level.warning;
      case 'error':
        return Level.error;
      case 'fatal':
        return Level.fatal;
      default:
        return Level.info;
    }
  }
}