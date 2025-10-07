import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

/// A simplified, modern logging utility that properly utilizes the `package:logging` library,
/// while maintaining a singleton pattern for access.
class LoggerUtil {
  // --- Singleton Setup ---
  static LoggerUtil? _instance;

  /// Private constructor
  LoggerUtil._internal();

  /// Public accessor for the singleton instance.
  static LoggerUtil get instance {
    _instance ??= LoggerUtil._internal();
    return _instance!;
  }

  // --- Instance Variables ---
  IOSink? _fileLogSink;
  String? _gameSessionDir;
  final DateFormat _fileNameFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
  final DateFormat _logTimestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  // --- Custom Log Levels ---
  static const Level debug = Level('DEBUG', 500);
  static const Level error = Level('ERROR', 1200);

  /// Initializes the logging system. Should be called once on the instance.
  void initialize({
    String logLevel = 'info',
    bool enableConsole = true,
    bool enableFile = true,
    bool useColors = true,
  }) {
    Logger.root.clearListeners();
    Logger.root.level = _levelFromString(logLevel);

    if (enableConsole) {
      Logger.root.onRecord.listen((record) {
        stdout.write(_formatRecord(record, useColors: useColors));
      });
    }

    if (enableFile) {
      _fileLogSink = _setupFileSink();
      if (_fileLogSink != null) {
        Logger.root.onRecord.listen((record) {
          _fileLogSink!.write(_formatRecord(record, useColors: false));
        });
      }
    }
  }

  // --- Public API ---
  String? get gameSessionDir => _gameSessionDir;

  void d(String message) => Logger.root.log(debug, message);

  void i(String message) => Logger.root.info(message);

  void w(String message) => Logger.root.warning(message);

  void e(String message, [Object? error, StackTrace? stackTrace]) =>
      Logger.root.log(LoggerUtil.error, message, error, stackTrace);

  Future<void> dispose() async {
    await _fileLogSink?.flush();
    await _fileLogSink?.close();
    _fileLogSink = null;
    // Setting instance to null allows for re-initialization in tests or hot-restarts
    _instance = null;
  }

  // --- Private Helpers ---
  String _formatRecord(LogRecord record, {required bool useColors}) {
    final timestamp = _logTimestampFormat.format(record.time);
    final level = record.level.name;
    final message = record.message;
    final logMessage = '[$timestamp] [$level] $message\n';

    if (useColors) {
      final color = _colorForLevel(record.level);
      const reset = '\x1B[0m';
      return '$color$logMessage$reset';
    }
    return logMessage;
  }

  IOSink? _setupFileSink() {
    try {
      const logDir = 'logs';
      final sessionName = _fileNameFormat.format(DateTime.now());
      _gameSessionDir = path.join(logDir, sessionName);
      final logDirObj = Directory(_gameSessionDir!);

      if (!logDirObj.existsSync()) {
        logDirObj.createSync(recursive: true);
      }

      const fileName = 'werewolf_arena.log';
      final fullPath = path.join(logDirObj.path, fileName);
      final logFile = File(fullPath);
      print('Log file created at: $fullPath');
      return logFile.openWrite(mode: FileMode.append);
    } catch (e) {
      print('Failed to setup file logging: $e');
      return null;
    }
  }

  Level _levelFromString(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return debug;
      case 'info':
        return Level.INFO;
      case 'warning':
      case 'warn':
        return Level.WARNING;
      case 'error':
        return error;
      default:
        return Level.INFO;
    }
  }

  String _colorForLevel(Level level) {
    if (level == error) return '\x1B[31m';
    if (level == Level.WARNING) return '\x1B[33m';
    if (level == Level.INFO) return '\x1B[37m';
    if (level == debug) return '\x1B[90m';
    return '\x1B[0m';
  }
}
