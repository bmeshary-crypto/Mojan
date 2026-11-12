/// رقم مختصر: 1500 → 1.5K، 2000000 → 2M.
String fmtK(int n) {
  String f(double v, String u) {
    final t = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '${t.endsWith('.0') ? t.substring(0, t.length - 2) : t}$u';
  }

  if (n >= 1000000000) return f(n / 1000000000, 'B');
  if (n >= 1000000) return f(n / 1000000, 'M');
  if (n >= 1000) return f(n / 1000, 'K');
  return '$n';
}
