import 'dart:math';

// Client-generated idempotency key for stock-writing submits (packing,
// wastage). The controller keeps the SAME id across retries of one
// submission and only rotates it after a confirmed success — so a
// resubmit after a timeout can't double-count stock (the backend
// upserts against a unique requestId index and replies "duplicate").
final Random _rng = Random();

// 2^31 - 1, not 1 << 32: compiled for the web, `1 << 32` is 0 (shifts
// there are 32-bit), and nextInt(0) throws — every submit that asked
// for an id failed before it was sent. This bound is the same on every
// platform, and two of them plus the microsecond clock are ample.
const _bound = 0x7fffffff;

String newRequestId() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r1 = _rng.nextInt(_bound).toRadixString(36);
  final r2 = _rng.nextInt(_bound).toRadixString(36);
  return 'req-$ts-$r1$r2';
}
