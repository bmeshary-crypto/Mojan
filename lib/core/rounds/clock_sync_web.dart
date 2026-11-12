import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// يقارن ساعة الجهاز بساعة سيرفر الموقع (هيدر Date)، حتى لو ساعة الجوال
/// غلط بكم ثانية تبقى الجولات متطابقة مع الباقين.
Future<Duration?> serverClockOffset() async {
  Duration? best;
  var bestRtt = 1 << 30;
  for (var i = 0; i < 3; i++) {
    try {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      final res = await web.window
          .fetch('build_id.txt?c=$t0'.toJS, web.RequestInit(method: 'HEAD', cache: 'no-store'))
          .toDart;
      final t1 = DateTime.now().millisecondsSinceEpoch;
      final date = res.headers.get('date');
      if (date == null) continue;
      final server = _parseHttpDate(date);
      if (server == null) continue;
      final rtt = t1 - t0;
      if (rtt < bestRtt) {
        bestRtt = rtt;
        // الهيدر بدقة ثانية، فنضيف نص ثانية كمتوسط
        best = Duration(milliseconds: server + 500 - (t0 + t1) ~/ 2);
      }
    } catch (_) {}
  }
  // فرق أقل من ثانية ما يستاهل (دقة الهيدر ثانية)
  if (best != null && best.inMilliseconds.abs() < 1000) return Duration.zero;
  return best;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Thu, 12 Nov 2026 12:40:01 GMT" → ميلي ثانية.
int? _parseHttpDate(String s) {
  final p = s.split(' ');
  if (p.length < 5) return null;
  final m = _months.indexOf(p[2]) + 1;
  final hms = p[4].split(':');
  if (m == 0 || hms.length != 3) return null;
  return DateTime.utc(int.parse(p[3]), m, int.parse(p[1]), int.parse(hms[0]), int.parse(hms[1]), int.parse(hms[2]))
      .millisecondsSinceEpoch;
}
