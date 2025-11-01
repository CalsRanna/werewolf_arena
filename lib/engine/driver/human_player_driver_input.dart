/// 输入读取器接口
///
/// 提供了一个抽象层，用于读取用户输入。
/// 这个接口允许不同的实现方式（控制台、GUI、测试mock等）
/// 而不让引擎层依赖具体的UI实现。
abstract class HumanPlayerDriverInput {
  /// 读取一行用户输入
  ///
  /// 返回用户输入的字符串，如果读取失败或用户取消返回 null。
  /// 实现者应该处理好 spinner、UI 更新等外部问题。
  String? readLine();
}
