import 'dart:async';
import 'package:werewolf_arena/core/drivers/player_driver.dart';
import 'package:werewolf_arena/core/state/game_state.dart';

/// 人类玩家驱动器
/// 
/// 用于人类玩家的驱动器实现，通过UI等待人类输入决策
class HumanPlayerDriver implements PlayerDriver {
  /// 用于接收外部输入的StreamController
  final StreamController<Map<String, dynamic>> _inputController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// 当前正在等待的提示信息
  String? _currentPrompt;
  
  /// 当前期望的格式
  String? _currentExpectedFormat;
  
  /// 是否正在等待输入
  bool _isWaitingForInput = false;

  @override
  Future<Map<String, dynamic>> generateSkillResponse({
    required dynamic player,
    required GameState state,
    required String skillPrompt,
    required String expectedFormat,
  }) async {
    // 设置当前等待状态
    _currentPrompt = skillPrompt;
    _currentExpectedFormat = expectedFormat;
    _isWaitingForInput = true;
    
    try {
      // 等待人类输入
      return await _waitForHumanInput(skillPrompt, expectedFormat);
    } finally {
      // 清理等待状态
      _isWaitingForInput = false;
      _currentPrompt = null;
      _currentExpectedFormat = null;
    }
  }
  
  /// 等待人类输入
  /// 
  /// 通过Stream等待外部UI提供的用户决策
  Future<Map<String, dynamic>> _waitForHumanInput(String prompt, String format) async {
    // 等待通过submitInput方法提交的输入
    final completer = Completer<Map<String, dynamic>>();
    
    StreamSubscription? subscription;
    subscription = _inputController.stream.listen((input) {
      // 收到输入后，完成Future并取消订阅
      subscription?.cancel();
      completer.complete(input);
    });
    
    // 设置超时（可选）
    const timeout = Duration(minutes: 10); // 给人类玩家10分钟思考时间
    
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      // 超时时返回空决策
      subscription.cancel();
      return {};
    }
  }
  
  /// 提交人类玩家的输入
  /// 
  /// 供外部UI调用，提交人类玩家的决策
  /// 
  /// [input] 人类玩家的决策，格式应符合当前技能的要求
  void submitInput(Map<String, dynamic> input) {
    if (_isWaitingForInput) {
      _inputController.add(input);
    }
  }
  
  /// 取消当前等待的输入
  /// 
  /// 供外部UI调用，取消当前的决策等待
  void cancelInput() {
    if (_isWaitingForInput) {
      _inputController.add({}); // 提交空决策
    }
  }
  
  /// 获取当前等待的提示信息
  /// 
  /// 供外部UI查询当前需要人类玩家做什么决策
  String? get currentPrompt => _currentPrompt;
  
  /// 获取当前期望的响应格式
  /// 
  /// 供外部UI了解应该以什么格式提交决策
  String? get currentExpectedFormat => _currentExpectedFormat;
  
  /// 是否正在等待人类输入
  bool get isWaitingForInput => _isWaitingForInput;
  
  /// 释放资源
  /// 
  /// 关闭StreamController，清理资源
  void dispose() {
    _inputController.close();
  }
}