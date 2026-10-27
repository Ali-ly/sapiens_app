/// Semantic JSON equality: map insertion order does not affect idempotency.
bool sameJson(Object? a, Object? b) {
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => sameJson(a[i], b[i]));
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && sameJson(a[k], b[k]));
  }
  return a == b;
}

bool isJsonPrefix(List<dynamic> before, List<dynamic> after) =>
    after.length >= before.length &&
    List.generate(before.length, (i) => i)
        .every((i) => sameJson(before[i], after[i]));
