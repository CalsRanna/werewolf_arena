import 'package:flutter/material.dart';

/// 响应式布局工具类
/// 提供屏幕尺寸判断和响应式布局辅助方法
class Responsive {
  /// 小屏断点 (手机)
  static const double mobileBreakpoint = 768;

  /// 中屏断点 (平板)
  static const double tabletBreakpoint = 1200;

  /// 判断是否为手机屏幕
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// 判断是否为平板屏幕
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// 判断是否为桌面屏幕
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// 获取当前屏幕类型
  static ScreenType getScreenType(BuildContext context) {
    if (isMobile(context)) return ScreenType.mobile;
    if (isTablet(context)) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// 根据屏幕尺寸返回不同的值
  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// 根据屏幕类型构建不同的Widget
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// 获取响应式的内边距
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return EdgeInsets.all(responsiveValue(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    ));
  }

  /// 获取响应式的卡片边距
  static EdgeInsets getResponsiveCardMargin(BuildContext context) {
    return EdgeInsets.all(responsiveValue(
      context,
      mobile: 8.0,
      tablet: 12.0,
      desktop: 16.0,
    ));
  }

  /// 获取响应式的网格列数
  static int getGridCrossAxisCount(BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// 获取响应式的宽高比
  static double getGridChildAspectRatio(BuildContext context, {
    double mobile = 1.0,
    double tablet = 1.2,
    double desktop = 1.6,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// 获取响应式的最大宽度
  static double getMaxWidth(BuildContext context) {
    return responsiveValue(
      context,
      mobile: double.infinity,
      tablet: 800.0,
      desktop: 1200.0,
    );
  }

  /// 判断是否应该使用横向布局
  static bool shouldUseHorizontalLayout(BuildContext context) {
    return !isMobile(context);
  }

  /// 获取响应式的字体大小
  static double getResponsiveFontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.1,
      desktop: desktop ?? mobile * 1.2,
    );
  }

  /// 获取响应式的图标大小
  static double getResponsiveIconSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.2,
      desktop: desktop ?? mobile * 1.5,
    );
  }
}

/// 屏幕类型枚举
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// 响应式布局构建器Widget
/// 简化响应式布局的创建
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return Responsive.builder(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

/// 响应式布局包装器
/// 自动应用响应式的padding和约束
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final bool applyCenterConstraint;
  final bool applyPadding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.applyCenterConstraint = false,
    this.applyPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (applyPadding) {
      content = Padding(
        padding: Responsive.getResponsivePadding(context),
        child: content,
      );
    }

    if (applyCenterConstraint) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.getMaxWidth(context),
          ),
          child: content,
        ),
      );
    }

    return content;
  }
}
