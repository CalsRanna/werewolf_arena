import 'dart:math';

class RandomHelper {
  static final RandomHelper _instance = RandomHelper._internal();
  final Random _random = Random();

  RandomHelper._internal();

  factory RandomHelper() {
    return _instance;
  }

  int nextInt(int max) {
    return _random.nextInt(max);
  }

  double nextDouble() {
    return _random.nextDouble();
  }

  bool nextBool() {
    return _random.nextBool();
  }

  T randomChoice<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }
    return items[_random.nextInt(items.length)];
  }

  List<T> shuffle<T>(List<T> items) {
    final shuffled = List<T>.from(items);
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }

  double nextDoubleRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  String nextString(int length, {String charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'}) {
    if (length <= 0) {
      return '';
    }

    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(charset[_random.nextInt(charset.length)]);
    }
    return buffer.toString();
  }
}