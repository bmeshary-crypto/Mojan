import 'dart:async';

import 'package:flutter/foundation.dart';

/// القيود اللي تقدر الإدارة تحطها على حساب بدل الحظر الكامل.
const banLimits = {
  'rooms': 'دخول الغرف الصوتية',
  'mic': 'الصعود على المايك',
  'chat': 'الكتابة في دردشة الغرف',
  'coins': 'صرف العملات (رهانات وهدايا ومتجر)',
};

/// حظر أو قيود من الإدارة، مع مدة اختيارية (بدون مدة = دائم).
class BanInfo {
  const BanInfo({this.full = false, this.until, this.limits = const {}, this.reason = ''});

  final bool full;
  final DateTime? until;
  final Set<String> limits;
  final String reason;

  bool activeAt(DateTime now) => (full || limits.isNotEmpty) && (until == null || until!.isAfter(now));
  bool get active => activeAt(DateTime.now());

  /// يقبل الصيغة القديمة (banned: true) والجديدة (banned: {...}).
  static BanInfo? parse(Object? v) {
    if (v == true) return const BanInfo(full: true);
    if (v is! Map) return null;
    final u = v['until'];
    return BanInfo(
      full: v['full'] == true,
      until: u is num ? DateTime.fromMillisecondsSinceEpoch(u.toInt()) : null,
      limits: {for (final l in (v['limits'] as List? ?? const [])) if (l is String) l},
      reason: v['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'full': full,
    'until': until?.millisecondsSinceEpoch,
    'limits': limits.toList(),
    'reason': reason,
    'at': DateTime.now().millisecondsSinceEpoch,
  };

  /// "لمدة 5 ساعات" / "لمدة 3 أيام" / "دائم".
  String remaining([DateTime? now]) {
    if (until == null) return 'دائم';
    final d = until!.difference(now ?? DateTime.now());
    if (d.inDays >= 1) return 'باقي ${d.inDays} يوم و${d.inHours % 24} ساعة';
    if (d.inHours >= 1) return 'باقي ${d.inHours} ساعة و${d.inMinutes % 60} دقيقة';
    return 'باقي ${d.inMinutes.clamp(1, 59)} دقيقة';
  }

  String describe() {
    final what = full ? 'حظر كامل' : 'منع من: ${limits.map((l) => banLimits[l] ?? l).join('، ')}';
    return '$what • ${remaining()}${reason.isEmpty ? '' : ' • السبب: $reason'}';
  }
}

/// حالة حظر/قيود الحساب الحالي، تتحدث من السحابة وتنتهي لحالها عند انتهاء المدة.
class Restrictions {
  Restrictions._();
  static final instance = Restrictions._();

  final current = ValueNotifier<BanInfo?>(null);

  /// حظر كامل فعال الآن.
  final fullBan = ValueNotifier<bool>(false);
  Timer? _expiry;

  void set(BanInfo? b) {
    _expiry?.cancel();
    final live = b != null && b.active ? b : null;
    current.value = live;
    fullBan.value = live?.full == true;
    final until = live?.until;
    if (until != null) {
      final wait = until.difference(DateTime.now());
      _expiry = Timer(wait + const Duration(seconds: 1), () => set(null));
    }
  }

  /// رسالة المنع لو الحساب ممنوع من [limit]، وإلا null.
  String? check(String limit) {
    final b = current.value;
    if (b == null || !b.active) return null;
    if (b.full || b.limits.contains(limit)) {
      return 'حسابك ممنوع من ${banLimits[limit] ?? limit} من الإدارة (${b.remaining()})';
    }
    return null;
  }
}
