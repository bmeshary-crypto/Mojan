import 'package:flutter/material.dart';

import '../core/firebase/cloud.dart';
import '../core/firebase/support.dart';
import '../core/theme.dart';
import '../widgets/account_widgets.dart';
import '../widgets/animated_background.dart';

/// يفتح صفحة «تواصل مع الإدارة». [draft] نص جاهز في خانة الكتابة (مثل طلب شحن باقة).
/// [userId] للأدمن: يفتح محادثة لاعب معيّن.
void openSupport(BuildContext context, {String? draft, String? userId, String? userName}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SupportScreen(draft: draft, userId: userId, userName: userName),
  ));
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.draft, this.userId, this.userName});
  final String? draft;
  final String? userId;
  final String? userName;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final _input = TextEditingController(text: widget.draft ?? '');
  Map<String, dynamic>? _admin;
  bool _sending = false;

  bool get _asAdmin => widget.userId != null;
  String? get _chatId => widget.userId ?? Cloud.instance.uid;

  @override
  void initState() {
    super.initState();
    if (Support.instance.available) {
      if (!_asAdmin) {
        Support.instance.adminProfile().then((a) {
          if (mounted) setState(() => _admin = a);
        });
      }
      final id = _chatId;
      if (id != null) Support.instance.markRead(id, asAdmin: _asAdmin).ignore();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final id = _chatId;
    final t = _input.text.trim();
    if (t.isEmpty || id == null || _sending) return;
    setState(() => _sending = true);
    try {
      await Support.instance.send(id, t, asAdmin: _asAdmin);
      _input.clear();
    } catch (_) {
      _toast('ما قدرنا نرسل، جرّب مرة ثانية');
    }
    if (mounted) setState(() => _sending = false);
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
  }

  Future<void> _grant() async {
    final ctl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('إرسال عملات لـ ${widget.userName ?? 'اللاعب'}'),
        content: TextField(
          key: const ValueKey('support-grant-amount'),
          controller: ctl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'عدد العملات'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(ctl.text.trim())), child: const Text('أرسل')),
        ],
      ),
    );
    if (n == null || n <= 0 || widget.userId == null) return;
    await Cloud.instance.adminGrant(widget.userId!, n);
    await Support.instance.send(widget.userId!, 'تم شحن $n عملة لحسابك 🪙 بالتوفيق!', asAdmin: true);
    _toast('أرسلنا $n عملة ✅');
  }

  @override
  Widget build(BuildContext context) {
    final online = Support.instance.available;
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, size: 28)),
              Expanded(
                child: Text(_asAdmin ? 'محادثة ${widget.userName ?? 'لاعب'}' : 'تواصل مع الإدارة',
                    style: AppTheme.display.copyWith(fontSize: 22)),
              ),
              if (_asAdmin)
                TextButton.icon(
                  key: const ValueKey('support-grant'),
                  onPressed: _grant,
                  icon: const Text('🪙'),
                  label: const Text('شحن'),
                ),
            ]),
            if (!_asAdmin) _adminCard(),
            Expanded(
              child: !online
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'المحادثة مع الإدارة تعمل في الموقع الرسمي بعد تسجيل الدخول.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  : StreamBuilder<List<SupportMsg>>(
                      stream: Support.instance.messages(_chatId!),
                      builder: (context, snap) {
                        final msgs = snap.data ?? const <SupportMsg>[];
                        if (msgs.isEmpty) {
                          return Center(
                            child: Text(_asAdmin ? 'لا توجد رسائل' : 'اكتب رسالتك وبيرد عليك الأدمن هنا 💬',
                                style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                          );
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) => _bubble(msgs[msgs.length - 1 - i]),
                        );
                      },
                    ),
            ),
            if (online)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('support-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'اكتب رسالتك…',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('support-send'),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _adminCard() {
    final name = (_admin?['name'] as String?) ?? 'إدارة MOJAN';
    final avatar = (_admin?['avatar'] as num?)?.toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GlassCard(
        child: Row(children: [
          if (avatar != null)
            PlayerAvatar(index: avatar, size: 56)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/images/brand_icon.webp', width: 56, height: 56),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                  child: const Text('الإدارة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('لشحن العملات أو أي مشكلة راسلنا هنا، والرد يوصلك في نفس الصفحة.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(SupportMsg m) {
    final mine = m.fromAdmin == _asAdmin;
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF6C3BFF) : Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.fromAdmin && !_asAdmin)
            const Text('الإدارة', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900)),
          Text(m.text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
