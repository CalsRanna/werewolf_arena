import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class BootstrapViewModel {
  bool _isInitialized = false;

  /// 初始化信号
  Future<void> initSignals() async {
    if (_isInitialized) return;

    // 模拟初始化过程
    await Future.delayed(Duration(seconds: 2));

    _isInitialized = true;
  }

  /// 导航到主页
  void navigateToHome(BuildContext context) {
    HomeRoute().push(context);
  }

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
}