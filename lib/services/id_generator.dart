import 'dart:math';

final Random _idRandom = Random();

String generateTextId([String prefix = 'id']) {
  final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
  final randomPart = _idRandom.nextInt(1 << 32).toRadixString(16);
  return '${prefix}_$micros$randomPart';
}
