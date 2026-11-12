import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/firebase/cloud.dart';
import '../../core/game_module.dart';
import '../../core/online/online_ludo.dart';
import '../../core/theme.dart';
import '../../widgets/account_widgets.dart';
import '../../widgets/animated_background.dart';
import 'ludo_screen.dart';

/// لودو أونلاين: الغرف المفتوحة، لعب سريع، وغرفة انتظار. إذا ما دخل أحد يكمل لاعب ذكاء اصطناعي.
class LudoOnlineLobby extends StatefulWidget {
  const LudoOnlineLobby({super.key});

  /// كم ثانية ننتظر لاعبين حقيقيين قبل ما يدخل الذكاء الاصطناعي.
  static const waitSeconds = 20;

  @override
  State<LudoOnlineLobby> createState() => _LudoOnlineLobbyState();
}

class _LudoOnlineLobbyState extends State<LudoOnlineLobby> {
  final svc = OnlineLudo.instance;
  bool _ready = false;
  bool _working = false;
  String? _matchId;
  OnlineMatch? _match;
  StreamSubscription<OnlineMatch?>? _sub;
  Timer? _tick;
  int _left = LudoOnlineLobby.waitSeconds;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    Cloud.instance.ready.then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  Future<void> _run(Future<String?> Function() f) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final id = await f();
      if (id != null) _enter(id);
    } catch (e) {
      _toast('صار خطأ في الاتصال، جرّب مرة ثانية');
    }
    if (mounted) setState(() => _working = false);
  }

  void _enter(String id) {
    _sub?.cancel();
    _matchId = id;
    _left = LudoOnlineLobby.waitSeconds;
    _launched = false;
    _sub = svc.watch(id).listen(_onMatch);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final m = _match;
      if (m == null || m.status != 'waiting') return;
      setState(() => _left = (_left - 1).clamp(0, 999));
      if (_left % 8 == 0) svc.heartbeat(m.id);
      // عند انتهاء الوقت تُملأ المقاعد بالذكاء الاصطناعي عند انتهاء الوقت
      if (_left == 0) svc.fillAiAndStart(m);
    });
  }

  void _onMatch(OnlineMatch? m) {
    if (!mounted) return;
    if (m == null || m.status == 'closed') {
      _reset();
      if (m?.host != svc.uid) _toast('صاحب الغرفة قفلها');
      return;
    }
    setState(() => _match = m);
    if (m.status == 'playing' && !_launched) {
      _launched = true;
      _tick?.cancel();
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LudoOnlineScreen(match: m)))
          .then((_) => _reset());
    }
  }

  void _reset() {
    _sub?.cancel();
    _tick?.cancel();
    if (mounted) {
      setState(() {
        _matchId = null;
        _match = null;
      });
    }
  }

  Future<void> _leaveWaiting() async {
    final m = _match;
    _reset();
    if (m != null) await svc.leave(m);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _matchId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveWaiting();
      },
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [
                  Row(children: [
                    IconButton(
                      onPressed: () => _matchId != null ? _leaveWaiting() : Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 28),
                    ),
                    Text('لودو أونلاين', style: AppTheme.display.copyWith(fontSize: 24)),
                  ]),
                  Expanded(
                    child: !_ready
                        ? const Center(child: CircularProgressIndicator())
                        : !svc.available
                            ? _offline()
                            : _matchId != null
                                ? _waiting()
                                : _lobby(),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offline() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🌐', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          const Text(
            'اللعب أونلاين يحتاج تسجيل الدخول من موقع MOJAN الرسمي.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('online-vs-ai'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LudoScreen(mode: PlayMode.vsComputer)),
            ),
            icon: const Icon(Icons.smart_toy_rounded),
            label: const Text('العب ضد الكمبيوتر'),
          ),
        ]),
      );

  Widget _lobby() {
    return ListView(padding: const EdgeInsets.all(14), children: [
      Row(children: [
        Expanded(
          child: _bigButton(
            key: const ValueKey('online-quick-2'),
            icon: '⚡',
            title: 'لعب سريع',
            sub: 'لاعبين',
            onTap: () => _run(() => svc.quick('ludo', 2)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _bigButton(
            key: const ValueKey('online-quick-4'),
            icon: '👥',
            title: 'لعب سريع',
            sub: '4 لاعبين',
            onTap: () => _run(() => svc.quick('ludo', 4)),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      const Text(
        'إذا ما لقينا أحد خلال ${LudoOnlineLobby.waitSeconds} ثانية يدخل معك لاعب ذكاء اصطناعي 🤖',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      const Text('غرف مفتوحة الحين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 8),
      StreamBuilder<List<OnlineMatch>>(
        stream: svc.openMatches('ludo'),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return GlassCard(
              child: Text(
                snap.hasError ? 'تعذر تحميل الغرف' : 'ما فيه غرف مفتوحة. اضغط لعب سريع وبتفتح غرفتك ويشوفها الكل.',
                style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
              ),
            );
          }
          return Column(children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    PlayerAvatar(
                      index: m.seats.whereType<OnlineSeat>().firstOrNull?.avatar ?? 0,
                      size: 42,
                      ring: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('غرفة ${m.hostName}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text('${m.filled}/${m.size} لاعبين · كلاسيك',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                      ]),
                    ),
                    FilledButton(
                      onPressed: m.host == svc.uid
                          ? () => _enter(m.id)
                          : () => _run(() async => await svc.join(m.id) ? m.id : null),
                      child: const Text('دخول'),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('online-create-2'),
            onPressed: () => _run(() => svc.create('ludo', 2)),
            child: const Text('افتح غرفة (2)'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('online-create-4'),
            onPressed: () => _run(() => svc.create('ludo', 4)),
            child: const Text('افتح غرفة (4)'),
          ),
        ),
      ]),
    ]);
  }

  Widget _bigButton({required Key key, required String icon, required String title, required String sub, required VoidCallback onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(22),
          onTap: _working ? null : onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B85), AppColors.ludo]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(children: [
              Text(icon, style: const TextStyle(fontSize: 30)),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(sub, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Widget _waiting() {
    final m = _match;
    if (m == null) return const Center(child: CircularProgressIndicator());
    final host = m.host == svc.uid;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(host ? 'غرفتك مفتوحة 🎲' : 'دخلت غرفة ${m.hostName}',
          textAlign: TextAlign.center, style: AppTheme.display.copyWith(fontSize: 22)),
      const SizedBox(height: 6),
      Text('ننتظر لاعبين… ${m.filled}/${m.size}',
          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: [
        for (final seat in m.seats)
          SizedBox(
            width: 90,
            child: Column(children: [
              seat == null
                  ? Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Icon(Icons.hourglass_top_rounded, color: Colors.white38),
                    )
                  : PlayerAvatar(index: seat.avatar, size: 64),
              const SizedBox(height: 4),
              Text(seat?.name ?? 'فاضي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
      ]),
      const SizedBox(height: 20),
      Text(
        _left > 0 ? 'إذا ما دخل أحد خلال $_left ثانية يكمل معك لاعب ذكاء اصطناعي 🤖' : 'يدخل الذكاء الاصطناعي الحين…',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      if (host)
        FilledButton.icon(
          key: const ValueKey('online-start-now'),
          onPressed: () => svc.fillAiAndStart(m),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('ابدأ الحين (الباقي ذكاء اصطناعي)'),
        ),
      const SizedBox(height: 8),
      TextButton(onPressed: _leaveWaiting, child: const Text('خروج من الغرفة')),
    ]);
  }
}
