import 'dart:math';

/// 游戏随机数生成工具类
/// 封装随机数生成逻辑，提供游戏相关的随机方法
class GameRandom {
  final Random _random;
  
  /// 获取内部的Random实例（为了与旧代码兼容）
  Random get generator => _random;
  
  /// 默认构造函数，使用系统随机种子
  GameRandom() : _random = Random();
  
  /// 使用指定种子的构造函数，用于测试或可重现的随机序列
  GameRandom.withSeed(int seed) : _random = Random(seed);
  
  /// 生成指定范围内的随机整数 [min, max)
  int nextInt(int max) => _random.nextInt(max);
  
  /// 生成指定范围内的随机整数 [min, max]
  int nextIntInRange(int min, int max) {
    if (min >= max) {
      throw ArgumentError('min ($min) must be less than max ($max)');
    }
    return min + _random.nextInt(max - min + 1);
  }
  
  /// 生成随机双精度浮点数 [0.0, 1.0)
  double nextDouble() => _random.nextDouble();
  
  /// 生成随机布尔值
  bool nextBool() => _random.nextBool();
  
  /// 从列表中随机选择一个元素
  T choice<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot choose from empty list');
    }
    return items[nextInt(items.length)];
  }
  
  /// 从列表中随机选择多个元素（不重复）
  List<T> choices<T>(List<T> items, int count) {
    if (count > items.length) {
      throw ArgumentError('Cannot choose $count items from list of ${items.length}');
    }
    if (count <= 0) {
      return [];
    }
    
    final shuffled = List<T>.from(items);
    shuffle(shuffled);
    return shuffled.take(count).toList();
  }
  
  /// 打乱列表顺序
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }
  
  /// 返回打乱后的新列表，不修改原列表
  List<T> shuffled<T>(List<T> list) {
    final result = List<T>.from(list);
    shuffle(result);
    return result;
  }
  
  /// 按权重随机选择
  T weightedChoice<T>(List<T> items, List<double> weights) {
    if (items.length != weights.length) {
      throw ArgumentError('Items and weights must have the same length');
    }
    if (items.isEmpty) {
      throw ArgumentError('Cannot choose from empty list');
    }
    
    final totalWeight = weights.fold(0.0, (sum, weight) => sum + weight);
    if (totalWeight <= 0) {
      throw ArgumentError('Total weight must be positive');
    }
    
    final random = nextDouble() * totalWeight;
    double cumulativeWeight = 0.0;
    
    for (int i = 0; i < items.length; i++) {
      cumulativeWeight += weights[i];
      if (random <= cumulativeWeight) {
        return items[i];
      }
    }
    
    // 防止浮点数精度问题，返回最后一个元素
    return items.last;
  }
  
  /// 生成随机字符串
  String nextString(int length, {String charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'}) {
    if (length <= 0) {
      return '';
    }
    
    final result = StringBuffer();
    for (int i = 0; i < length; i++) {
      result.write(charset[nextInt(charset.length)]);
    }
    return result.toString();
  }
  
  /// 按概率返回true
  bool chance(double probability) {
    if (probability < 0.0 || probability > 1.0) {
      throw ArgumentError('Probability must be between 0.0 and 1.0');
    }
    return nextDouble() < probability;
  }
}