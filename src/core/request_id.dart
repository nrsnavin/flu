import 'dart:math';

// Client-generated idempotency key for stock-writing submits (packing,
// wastage). The controller keeps the SAME id across retries of one
// submission and only rotates it after a confirmed success — so a
// resubmit after a timeout can't double-count stock (the backend
// upserts against a unique requestId index and replies "duplicate").
final Random _rng = Random();

String newRequestId() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r1 = _rng.nextInt(1 << 32).toRadixString(36);
  final r2 = _rng.nextInt(1 << 32).toRadixString(36);
  return 'req-$ts-$r1$r2';
}
