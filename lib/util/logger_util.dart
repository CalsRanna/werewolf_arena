import 'package:logger/logger.dart';

/// 简化的日志系统 - 单例模式，支持控制台和文件输出
class LoggerUtil {
  static LoggerUtil? _instance;
  final _logger = Logger(printer: PlainPrinter());

  LoggerUtil._internal();

  /// 获取单例实例
  static LoggerUtil get instance => _instance ??= LoggerUtil._internal();

  /// 调试日志
  void d(String message) {
    _logger.d(message);
  }

  /// 信息日志
  void i(String message) {
    _logger.i(message);
  }

  /// 警告日志
  void w(String message) {
    _logger.w(message);
  }

  /// 错误日志
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}

class PlainPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final level = event.level.name.toUpperCase();
    final time = event.time.toString().substring(0, 19);
    return ['[$level][$time] ${event.message}'];
  }
}
