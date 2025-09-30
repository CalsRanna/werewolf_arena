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

  T weightedSelect<T>(List<T> items, List<double> weights) {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }
    if (items.length != weights.length) {
      throw ArgumentError('Items and weights must have same length');
    }

    final totalWeight = weights.reduce((a, b) => a + b);
    final selection = _random.nextDouble() * totalWeight;

    double currentWeight = 0;
    for (int i = 0; i < items.length; i++) {
      currentWeight += weights[i];
      if (selection <= currentWeight) {
        return items[i];
      }
    }

    return items.last;
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

  List<T> sample<T>(List<T> items, int count, {bool allowDuplicates = false}) {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }
    if (count <= 0) {
      return [];
    }
    if (count > items.length && !allowDuplicates) {
      throw ArgumentError('Cannot sample $count items from ${items.length} without duplicates');
    }

    if (allowDuplicates) {
      return List.generate(count, (_) => randomChoice(items));
    } else {
      final shuffled = shuffle(items);
      return shuffled.take(count).toList();
    }
  }

  double nextDoubleRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  int nextIntRange(int min, int max) {
    return min + _random.nextInt(max - min + 1);
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

  DateTime nextDateTime({
    DateTime? min,
    DateTime? max,
  }) {
    final minTime = min?.millisecondsSinceEpoch ?? DateTime.now().subtract(const Duration(days: 365)).millisecondsSinceEpoch;
    final maxTime = max?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;

    return DateTime.fromMillisecondsSinceEpoch(
      _random.nextInt(maxTime - minTime) + minTime,
    );
  }

  Color nextColor() {
    return Color.fromARGB(
      255,
      _random.nextInt(256),
      _random.nextInt(256),
      _random.nextInt(256),
    );
  }

  String nextHexColor() {
    return '#${nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  bool probability(double probability) {
    if (probability < 0.0 || probability > 1.0) {
      throw ArgumentError('Probability must be between 0.0 and 1.0');
    }
    return _random.nextDouble() < probability;
  }

  T rouletteSelect<T>(List<T> items, List<double> fitnessScores) {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }
    if (items.length != fitnessScores.length) {
      throw ArgumentError('Items and fitness scores must have same length');
    }

    final totalFitness = fitnessScores.reduce((a, b) => a + b);
    final selection = _random.nextDouble() * totalFitness;

    double currentFitness = 0;
    for (int i = 0; i < items.length; i++) {
      currentFitness += fitnessScores[i];
      if (selection <= currentFitness) {
        return items[i];
      }
    }

    return items.last;
  }

  Map<T, double> normalizeWeights<T>(Map<T, double> weights) {
    if (weights.isEmpty) {
      return {};
    }

    final total = weights.values.reduce((a, b) => a + b);
    if (total == 0) {
      return Map.fromEntries(weights.entries.map((e) => MapEntry(e.key, 1.0 / weights.length)));
    }

    return weights.map((key, value) => MapEntry(key, value / total));
  }
}

class Color {
  final int a;
  final int r;
  final int g;
  final int b;

  const Color.fromARGB(this.a, this.r, this.g, this.b);

  String toHex() {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }
}