import 'dart:math';

final _rng = Random();

/// 짧은 임의 ID (웹앱과 같은 형식의 8자리 base36).
String newId() => List.generate(8, (_) => _rng.nextInt(36).toRadixString(36)).join();
