import 'package:werewolf_arena/core/engine/game_observer.dart';
import 'package:werewolf_arena/core/logging/game_log_event.dart';
import 'package:werewolf_arena/services/logging/logger.dart';

/// 日志观察者实现
/// 
/// 这个观察者专门处理游戏引擎的日志事件，
/// 将其转换为外部日志系统的调用
/// 
/// 这是一个桥接模式的实现：
/// - 游戏引擎产生纯净的日志事件
/// - 外部观察者决定如何处理这些事件
/// - 保持core模块的独立性
class GameLogObserver extends GameObserverAdapter {
  /// 是否启用日志输出
  final bool enabled;
  
  /// 最小日志级别
  final GameLogLevel minLogLevel;
  
  /// 日志类别过滤器（如果为空则记录所有类别）
  final Set<GameLogCategory>? categoryFilter;
  
  GameLogObserver({
    this.enabled = true,
    this.minLogLevel = GameLogLevel.debug,
    this.categoryFilter,
  });

  @override
  void onGameLog(GameLogEvent logEvent) {
    if (!enabled) return;
    
    // 检查日志级别
    if (_getLogLevelPriority(logEvent.level) < _getLogLevelPriority(minLogLevel)) {
      return;
    }
    
    // 检查类别过滤器
    if (categoryFilter != null && !categoryFilter!.contains(logEvent.category)) {
      return;
    }
    
    // 根据不同的日志级别使用不同的输出方法
    switch (logEvent.level) {
      case GameLogLevel.debug:
        LoggerUtil.instance.d(logEvent.message, LogCategory.debug);
        break;
      case GameLogLevel.info:
        LoggerUtil.instance.i(logEvent.message, LogCategory.general);
        break;
      case GameLogLevel.warning:
        LoggerUtil.instance.w(logEvent.message, LogCategory.general);
        break;
      case GameLogLevel.error:
        LoggerUtil.instance.e(
          logEvent.message,
          logEvent.metadata?['error'],
          null,
          LogCategory.error,
        );
        break;
    }
    
    // 同时也可以根据类别输出到专门的日志文件
    _logByCategory(logEvent);
  }
  
  /// 根据类别输出到专门的日志文件
  void _logByCategory(GameLogEvent logEvent) {
    switch (logEvent.category) {
      case GameLogCategory.engine:
        LoggerUtil.instance.i(logEvent.message, LogCategory.gameFlow);
        break;
      case GameLogCategory.skill:
      case GameLogCategory.player:
        LoggerUtil.instance.i(logEvent.message, LogCategory.aiDecision);
        break;
      default:
        // 其他类别已经在上面处理了
        break;
    }
  }
  
  /// 获取日志级别的优先级数值
  int _getLogLevelPriority(GameLogLevel level) {
    switch (level) {
      case GameLogLevel.debug:
        return 0;
      case GameLogLevel.info:
        return 1;
      case GameLogLevel.warning:
        return 2;
      case GameLogLevel.error:
        return 3;
    }
  }
}

/// 控制台日志观察者
/// 
/// 简单地将日志输出到控制台，适用于开发和调试
class ConsoleLogObserver extends GameObserverAdapter {
  final bool showTimestamp;
  final bool colorEnabled;

  ConsoleLogObserver({
    this.showTimestamp = true,
    this.colorEnabled = true,
  });

  @override
  void onGameLog(GameLogEvent logEvent) {
    final output = _formatLogMessage(logEvent);
    
    if (colorEnabled) {
      print(_colorizeMessage(output, logEvent.level));
    } else {
      print(output);
    }
  }

  String _formatLogMessage(GameLogEvent logEvent) {
    final buffer = StringBuffer();
    
    if (showTimestamp) {
      final timeStr = logEvent.timestamp.toString().substring(11, 19);
      buffer.write('[$timeStr] ');
    }
    
    buffer.write('[${logEvent.level.name.toUpperCase()}] ');
    buffer.write('[${logEvent.category.name.toUpperCase()}] ');
    
    if (logEvent.phase != null) {
      buffer.write('[${logEvent.phase!.displayName}] ');
    }
    
    if (logEvent.dayNumber != null) {
      buffer.write('[第${logEvent.dayNumber}天] ');
    }
    
    buffer.write(logEvent.message);
    
    return buffer.toString();
  }

  String _colorizeMessage(String message, GameLogLevel level) {
    // ANSI 色彩代码
    const String reset = '\x1B[0m';
    const String red = '\x1B[31m';
    const String yellow = '\x1B[33m';
    const String blue = '\x1B[34m';
    const String gray = '\x1B[90m';

    switch (level) {
      case GameLogLevel.debug:
        return '$gray$message$reset';
      case GameLogLevel.info:
        return '$blue$message$reset';
      case GameLogLevel.warning:
        return '$yellow$message$reset';
      case GameLogLevel.error:
        return '$red$message$reset';
    }
  }
}

/// 文件日志观察者
/// 
/// 将日志直接写入文件，可以配置不同的输出格式
class FileLogObserver extends GameObserverAdapter {
  final String filePath;
  final bool jsonFormat;
  
  // 这里可以添加文件写入逻辑
  // 为了简化示例，暂时只提供接口
  FileLogObserver({
    required this.filePath,
    this.jsonFormat = false,
  });

  @override
  void onGameLog(GameLogEvent logEvent) {
    // TODO: 实现文件写入逻辑
    // 可以使用异步写入、缓冲等优化技术
    if (jsonFormat) {
      _writeJsonLog(logEvent);
    } else {
      _writeTextLog(logEvent);
    }
  }
  
  void _writeJsonLog(GameLogEvent logEvent) {
    // 将事件转换为JSON格式并写入文件
    // final jsonStr = jsonEncode(logEvent.toJson());
    // File(filePath).writeAsStringSync('$jsonStr\n', mode: FileMode.append);
  }
  
  void _writeTextLog(GameLogEvent logEvent) {
    // 将事件转换为文本格式并写入文件
    // final textStr = logEvent.toString();
    // File(filePath).writeAsStringSync('$textStr\n', mode: FileMode.append);
  }
}