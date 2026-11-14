import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// الدولة والمدينة وعنوان الـ IP من خدمة مجانية (مع بديل لو تعطلت).
/// يرجع null لو كل الخدمات محجوبة.
Future<Map<String, String>?> lookupGeo() async {
  Future<Map<String, dynamic>?> get(String url) async {
    try {
      final res = await web.window.fetch(url.toJS, web.RequestInit(cache: 'no-store')).toDart;
      if (!res.ok) return null;
      final j = jsonDecode((await res.text().toDart).toDart);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  String s(Object? v) => v == null ? '' : '$v';

  final a = await get('https://get.geojs.io/v1/ip/geo.json');
  if (a != null && s(a['ip']).isNotEmpty) {
    return {
      'ip': s(a['ip']),
      'cc': s(a['country_code']),
      'country': s(a['country']),
      'city': s(a['city']),
      'region': s(a['region']),
      'isp': s(a['organization_name']),
      'tz': s(a['timezone']),
    };
  }
  final b = await get('https://ipwho.is/');
  if (b != null && b['success'] != false && s(b['ip']).isNotEmpty) {
    return {
      'ip': s(b['ip']),
      'cc': s(b['country_code']),
      'country': s(b['country']),
      'city': s(b['city']),
      'region': s(b['region']),
      'isp': s((b['connection'] as Map?)?['isp']),
      'tz': s((b['timezone'] as Map?)?['id']),
    };
  }
  return null;
}

/// نوع الجهاز من المتصفح: أندرويد/آيفون/ويندوز... + المتصفح.
String deviceInfo() {
  final ua = web.window.navigator.userAgent;
  final os = ua.contains('Android')
      ? 'أندرويد'
      : (ua.contains('iPhone') || ua.contains('iPad'))
          ? 'آيفون/آيباد'
          : ua.contains('Windows')
              ? 'ويندوز'
              : ua.contains('Mac OS')
                  ? 'ماك'
                  : ua.contains('Linux')
                      ? 'لينكس'
                      : 'غير معروف';
  final browser = ua.contains('wv)') || ua.contains('; wv')
      ? 'تطبيق'
      : ua.contains('Edg/')
          ? 'Edge'
          : ua.contains('SamsungBrowser')
              ? 'Samsung'
              : ua.contains('Chrome/')
                  ? 'Chrome'
                  : ua.contains('Safari/')
                      ? 'Safari'
                      : ua.contains('Firefox/')
                          ? 'Firefox'
                          : '';
  final standalone = web.window.matchMedia('(display-mode: standalone)').matches;
  return '$os${browser.isEmpty ? '' : ' • $browser'}${standalone ? ' • مثبّت كتطبيق' : ''}';
}
