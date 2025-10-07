import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

/// 日志类别枚举
enum LogCategory {
  gameFlow('game_flow.log'),
  aiDecision('ai_decisions.log'),
  llmApi('llm_api.log'),
  error('errors.log');

  const LogCategory(this.fileName);
  final String fileName;
}

/// 带缓冲的异步文件输出
class BufferedFileOutput extends LogOutput {
  final String filePath;
  final int bufferSize;
  final Duration flushInterval;

  IOSink? _sink;
  final Queue<String> _buffer = Queue<String>();
  Timer? _flushTimer;
  bool _disposed = false;

  BufferedFileOutput({
    required this.filePath,
    this.bufferSize = 50,
    this.flushInterval = const Duration(milliseconds: 500),
  });

  @override
  Future<void> init() async {
    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _sink = file.openWrite(mode: FileMode.append);

      // 启动定期刷新
      _flushTimer = Timer.periodic(flushInterval, (_) => _flush());
    } catch (e) {
      print('Failed to initialize log file at $filePath: $e');
    }
  }

  @override
  void output(OutputEvent event) {
    if (_disposed || _sink == null) return;

    for (var line in event.lines) {
      _buffer.add('$line\n');
    }

    // 缓冲区满时立即刷新
    if (_buffer.length >= bufferSize) {
      _flush();
    }
  }

  void _flush() {
    if (_buffer.isEmpty || _sink == null) return;

    try {
      while (_buffer.isNotEmpty) {
        _sink!.write(_buffer.removeFirst());
      }
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _flushTimer?.cancel();
    _flush(); // 最后一次刷新
    await _sink?.flush();
    await _sink?.close();
  }
}

/// 多文件分类输出（根据日志级别和类别分发到不同文件）
class MultiFileOutput extends LogOutput {
  final Map<LogCategory, BufferedFileOutput> _outputs;
  final BufferedFileOutput? _consoleOutput;

  MultiFileOutput({
    required Map<LogCategory, BufferedFileOutput> outputs,
    BufferedFileOutput? consoleOutput,
  })  : _outputs = outputs,
        _consoleOutput = consoleOutput;

  @override
  void output(OutputEvent event) {
    // 错误级别的日志始终写入 error.log
    if (event.level == Level.error || event.level == Level.fatal) {
      _outputs[LogCategory.error]?.output(event);
    }

    // 根据当前线程上下文确定类别（通过 Zone）
    final category = Zone.current[#logCategory] as LogCategory?;
    if (category != null && _outputs.containsKey(category)) {
      _outputs[category]?.output(event);
    } else {
      // 默认写入 game_flow.log
      _outputs[LogCategory.gameFlow]?.output(event);
    }

    // 同时输出到控制台
    _consoleOutput?.output(event);
  }

  Future<void> disposeAll() async {
    await Future.wait(_outputs.values.map((output) => output.dispose()));
    await _consoleOutput?.dispose();
  }
}

/// 自定义 Printer：简化格式，提高性能
class CompactPrinter extends LogPrinter {
  final DateFormat _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  final bool useColors;

  CompactPrinter({this.useColors = true});

  @override
  List<String> log(LogEvent event) {
    final timestamp = _timestampFormat.format(event.time);
    final level = event.level.name.toUpperCase().padRight(7);
    final message = event.message;

    final logLine = '[$timestamp] [$level] $message';

    if (useColors) {
      final color = _getColor(event.level);
      const reset = '\x1B[0m';
      return ['$color$logLine$reset'];
    }

    return [logLine];
  }

  String _getColor(Level level) {
    switch (level) {
      case Level.fatal:
      case Level.error:
        return '\x1B[31m'; // 红色
      case Level.warning:
        return '\x1B[33m'; // 黄色
      case Level.info:
        return '\x1B[37m'; // 白色
      case Level.debug:
      case Level.trace:
        return '\x1B[90m'; // 灰色
      default:
        return '\x1B[0m';
    }
  }
}

/// 简化的 Logger 工具类
class LoggerUtil {
  static LoggerUtil? _instance;
  static Logger? _logger;
  static MultiFileOutput? _multiOutput;
  static String? _gameSessionDir;

  LoggerUtil._internal();

  static LoggerUtil get instance {
    _instance ??= LoggerUtil._internal();
    return _instance!;
  }

  String? get gameSessionDir => _gameSessionDir;

  /// 初始化日志系统
  Future<void> initialize({
    String logLevel = 'info',
    bool enableConsole = true,
    bool enableFile = true,
    bool useColors = true,
  }) async {
    // 创建会话目录
    final dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
    final sessionName = dateFormat.format(DateTime.now());
    _gameSessionDir = path.join('logs', sessionName);

    // 初始化文件输出
    final fileOutputs = <LogCategory, BufferedFileOutput>{};

    if (enableFile) {
      for (final category in LogCategory.values) {
        final filePath = path.join(_gameSessionDir!, category.fileName);
        final output = BufferedFileOutput(filePath: filePath);
        await output.init();
        fileOutputs[category] = output;
      }
    }

    // 控制台输出（不使用缓冲）
    BufferedFileOutput? consoleOutput;
    if (enableConsole) {
      consoleOutput = _ConsoleOutput(useColors: useColors);
    }

    // 创建多文件输出
    _multiOutput = MultiFileOutput(
      outputs: fileOutputs,
      consoleOutput: consoleOutput,
    );

    // 配置 Logger
    _logger = Logger(
      filter: ProductionFilter(),
      printer: CompactPrinter(useColors: useColors),
      output: _multiOutput,
      level: _parseLevel(logLevel),
    );

    Logger.level = _parseLevel(logLevel);
  }

  // === 公共 API ===

  /// 普通日志方法
  void t(String message, [LogCategory? category]) =>
      _logWithCategory(Level.trace, message, category);

  void d(String message, [LogCategory? category]) =>
      _logWithCategory(Level.debug, message, category);

  void i(String message, [LogCategory? category]) =>
      _logWithCategory(Level.info, message, category);

  void w(String message, [LogCategory? category]) =>
      _logWithCategory(Level.warning, message, category);

  void e(String message,
          [Object? error, StackTrace? stackTrace, LogCategory? category]) =>
      _logWithCategory(Level.error, message, category, error, stackTrace);

  void f(String message,
          [Object? error, StackTrace? stackTrace, LogCategory? category]) =>
      _logWithCategory(Level.fatal, message, category, error, stackTrace);

  /// 带类别的日志记录
  void _logWithCategory(
    Level level,
    String message,
    LogCategory? category, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (category != null) {
      runZoned(
        () =>
            _logger?.log(level, message, error: error, stackTrace: stackTrace),
        zoneValues: {#logCategory: category},
      );
    } else {
      _logger?.log(level, message, error: error, stackTrace: stackTrace);
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    await _multiOutput?.disposeAll();
    _logger?.close();
    _logger = null;
    _multiOutput = null;
    _instance = null;
  }

  // === 私有辅助方法 ===

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

/// 控制台输出（直接写入 stdout，不使用缓冲）
class _ConsoleOutput extends BufferedFileOutput {
  final bool useColors;

  _ConsoleOutput({required this.useColors})
      : super(filePath: '', bufferSize: 1, flushInterval: Duration.zero);

  @override
  Future<void> init() async {
    // 控制台不需要初始化文件
  }

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      stdout.writeln(line);
    }
  }

  @override
  Future<void> dispose() async {
    // 控制台不需要清理
  }
}
