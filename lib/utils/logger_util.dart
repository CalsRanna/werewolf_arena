import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

/// 控制台颜色枚举
enum ConsoleColor {
  reset,
  red,
  green,
  yellow,
  blue,
  cyan,
  white,
  brightBlack;

  String get code {
    switch (this) {
      case reset:
        return '\x1B[0m';
      case red:
        return '\x1B[31m';
      case green:
        return '\x1B[32m';
      case yellow:
        return '\x1B[33m';
      case blue:
        return '\x1B[34m';
      case cyan:
        return '\x1B[36m';
      case white:
        return '\x1B[37m';
      case brightBlack:
        return '\x1B[90m';
    }
  }
}

/// 简化的统一日志工具类
/// 只提供 d、i、w、e 四个方法，支持添加到LLM上下文
class LoggerUtil {
  static LoggerUtil? _instance;

  // 配置
  bool _enableConsole = true;
  bool _enableFile = true;
  bool _useColors = true;
  String _logLevel = 'info';

  // 文件日志
  final String _logDir = 'logs';
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  final DateFormat _fileNameFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
  IOSink? _fileLogSink;

  // LLM上下文数组
  final List<String> _llmContext = [];
  static const int _maxContextSize = 100; // 最大上下文条数

  LoggerUtil._internal();

  /// 获取单例实例
  static LoggerUtil get instance {
    _instance ??= LoggerUtil._internal();
    return _instance!;
  }

  /// 初始化日志工具
  void initialize({
    bool enableConsole = true,
    bool enableFile = true,
    bool useColors = true,
    String logLevel = 'info',
    String? logFilePath,
  }) {
    _enableConsole = enableConsole;
    _enableFile = enableFile;
    _useColors = useColors;
    _logLevel = logLevel;

    _setupLogger();
    if (_enableFile) {
      _setupFileLogging(logFilePath);
    }
  }

  void _setupLogger() {
    Logger.root.level = _getLogLevel(_logLevel);
    Logger.root.clearListeners();
  }

  void _setupFileLogging(String? logFilePath) {
    try {
      final logDir = Directory(_logDir);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      final fileName = logFilePath ??
          'werewolf_arena_${_fileNameFormat.format(DateTime.now())}.log';
      final fullPath = path.join(_logDir, path.basename(fileName));
      final logFile = File(fullPath);
      _fileLogSink = logFile.openWrite(mode: FileMode.append);
    } catch (e) {
      if (_enableConsole) {
        stdout.writeln('Failed to setup file logging: $e');
      }
    }
  }

  /// Debug级别日志
  void d(String message, {bool addToLLMContext = false}) {
    _log('DEBUG', message, ConsoleColor.brightBlack, addToLLMContext);
  }

  /// Info级别日志
  void i(String message, {bool addToLLMContext = false}) {
    _log('INFO', message, ConsoleColor.white, addToLLMContext);
  }

  /// Warning级别日志
  void w(String message, {bool addToLLMContext = false}) {
    _log('WARNING', message, ConsoleColor.yellow, addToLLMContext);
  }

  /// Error级别日志
  void e(String message, {bool addToLLMContext = false}) {
    _log('ERROR', message, ConsoleColor.red, addToLLMContext);
  }

  /// 获取LLM上下文数组（只读）
  List<String> get llmContext => List.unmodifiable(_llmContext);

  /// 清空LLM上下文
  void clearLLMContext() {
    _llmContext.clear();
  }

  /// 内部日志方法
  void _log(
      String level, String message, ConsoleColor color, bool addToLLMContext) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logMessage = '[$timestamp] [$level] $message';

    // 控制台输出
    if (_enableConsole && _shouldLog(level)) {
      if (_useColors) {
        stdout.writeln('${color.code}$logMessage${ConsoleColor.reset.code}');
      } else {
        stdout.writeln(logMessage);
      }
    }

    // 文件日志
    if (_enableFile && _fileLogSink != null) {
      try {
        _fileLogSink!.writeln(logMessage);
      } catch (e) {
        if (_enableConsole) {
          stdout.writeln('Failed to write to log file: $e');
        }
      }
    }

    // 添加到LLM上下文
    if (addToLLMContext) {
      _addToLLMContext('[$level] $message');
    }
  }

  void _addToLLMContext(String message) {
    _llmContext.add(message);

    // 保持上下文大小在限制内
    while (_llmContext.length > _maxContextSize) {
      _llmContext.removeAt(0);
    }
  }

  bool _shouldLog(String level) {
    final levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
    final currentLevelIndex = levels.indexOf(_logLevel.toUpperCase());
    final messageLevelIndex = levels.indexOf(level);
    return messageLevelIndex >= currentLevelIndex;
  }

  Level _getLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Level('DEBUG', 300);
      case 'info':
        return Level('INFO', 800);
      case 'warning':
      case 'warn':
        return Level('WARNING', 900);
      case 'error':
        return Level('ERROR', 1000);
      default:
        return Level.INFO;
    }
  }

  /// 清理资源
  void dispose() {
    try {
      _fileLogSink?.close();
      _fileLogSink = null;
      _llmContext.clear();
    } catch (e) {
      if (_enableConsole) {
        stdout.writeln('Failed to dispose LoggerUtil: $e');
      }
    }
    _instance = null;
  }
}
