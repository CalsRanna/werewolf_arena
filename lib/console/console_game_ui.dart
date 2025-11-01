// ignore_for_file: avoid_print

import 'dart:io';

import 'package:cli_spin/cli_spin.dart';

/// 控制台颜色枚举
enum ConsoleColor { red, green, yellow, blue, magenta, cyan, white, gray, bold }

/// 游戏控制台显示工具类
///
/// 专注于游戏相关的控制台输出和格式化显示
/// 不包含任何日志记录功能,仅负责控制台界面的美化
class ConsoleGameUI {
  static ConsoleGameUI? _instance;

  static ConsoleGameUI get instance {
    _instance ??= ConsoleGameUI._internal();
    return _instance!;
  }

  bool _useColors = true;

  CliSpin? _currentSpinner;
  ConsoleGameUI._internal();

  /// 显示错误信息
  void displayError(String error, {Object? errorDetails}) {
    printLine();
    printLine(_colorize('❌ 错误: ', ConsoleColor.red) + error);
    if (errorDetails != null) {
      printLine('${_colorize('详情: ', ConsoleColor.gray)}$errorDetails');
    }
    printLine();
  }

  void dispose() {
    if (_currentSpinner == null) return;
    _currentSpinner!.stop();
    _currentSpinner = null;
  }

  /// 暂停spinner（输出内容前调用）
  void pauseSpinner() {
    if (_currentSpinner == null) return;
    _currentSpinner!.stop();
    _currentSpinner = null; // 清空引用，防止多个spinner同时运行
  }

  /// 恢复spinner（输出内容后调用）
  void resumeSpinner() {
    // 只有在没有spinner运行时才创建新的
    _currentSpinner ??= CliSpin(spinner: CliSpinners.dots).start();
  }

  void startSpinner() {
    _currentSpinner = CliSpin(spinner: CliSpinners.dots).start();
  }

  /// 初始化控制台设置
  void initialize({bool useColors = true}) {
    _useColors = useColors;
  }

  // === 基础输出方法 ===

  void printEvent(String text) {
    printLine(_colorize(text, ConsoleColor.green));
  }

  void printHeader(String title, {ConsoleColor color = ConsoleColor.cyan}) {
    final border = '=' * 60;
    printLine(_colorize(border, color));
    printLine(_colorize(title, color));
    printLine(_colorize(border, color));
    printLine();
  }

  void printLine([String? text]) {
    pauseSpinner();
    if (text != null) {
      stdout.writeln('● $text');
    } else {
      stdout.writeln();
    }
    resumeSpinner();
  }

  void printLog(String text) {
    pauseSpinner();
    stdout.writeln(text);
    resumeSpinner();
  }

  void printSeparator([String char = '-', int length = 40]) {
    printLine(_colorize(char * length, ConsoleColor.gray));
  }

  String? readLine() {
    stdout.write('请输入回车键继续');
    return stdin.readLineSync();
  }

  // === 颜色控制 ===

  String _colorize(String text, ConsoleColor color) {
    if (!_useColors || !stdout.hasTerminal) {
      return text;
    }

    final colorCode = _getColorCode(color);
    return '\x1B[${colorCode}m$text\x1B[0m';
  }

  // === 游戏相关显示方法 ===

  int _getColorCode(ConsoleColor color) {
    switch (color) {
      case ConsoleColor.red:
        return 31;
      case ConsoleColor.green:
        return 32;
      case ConsoleColor.yellow:
        return 33;
      case ConsoleColor.blue:
        return 34;
      case ConsoleColor.magenta:
        return 35;
      case ConsoleColor.cyan:
        return 36;
      case ConsoleColor.white:
        return 37;
      case ConsoleColor.gray:
        return 90;
      case ConsoleColor.bold:
        return 1;
    }
  }
}
