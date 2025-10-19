import 'package:flutter/material.dart';
import 'package:signals/signals.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class BootstrapViewModel {
  // Signals 状态管理
  final Signal<bool> isInitialized = signal(false);
  final Signal<String> initializationMessage = signal('正在初始化游戏引擎...');
  final Signal<double> initializationProgress = signal(0.0);
  final Signal<String?> errorMessage = signal(null);

  /// 初始化应用
  Future<void> initSignals() async {
    if (isInitialized.value) return;

    try {
      // 步骤 1: 初始化配置服务
      initializationMessage.value = '正在加载配置...';
      initializationProgress.value = 0.2;
      await Future.delayed(Duration(milliseconds: 300));

      // 步骤 2: 初始化游戏服务
      initializationMessage.value = '正在初始化游戏引擎...';
      initializationProgress.value = 0.5;
      await Future.delayed(Duration(milliseconds: 300));

      // 步骤 3: 预加载场景
      initializationMessage.value = '正在加载游戏场景...';
      initializationProgress.value = 0.8;
      await Future.delayed(Duration(milliseconds: 300));

      // 完成初始化
      initializationMessage.value = '初始化完成！';
      initializationProgress.value = 1.0;
      await Future.delayed(Duration(milliseconds: 500));

      isInitialized.value = true;
    } catch (e) {
      errorMessage.value = '初始化失败: $e';

      // 即使失败也标记为已初始化，让用户可以进入应用尝试手动修复
      isInitialized.value = true;
    }
  }

  /// 导航到主页
  void navigateToHome(BuildContext context) {
    HomeRoute().push(context);
  }

  /// 重试初始化
  Future<void> retry() async {
    isInitialized.value = false;
    errorMessage.value = null;
    initializationProgress.value = 0.0;
    await initSignals();
  }

  /// 清理资源
  void dispose() {
    isInitialized.dispose();
    initializationMessage.dispose();
    initializationProgress.dispose();
    errorMessage.dispose();
  }
}
