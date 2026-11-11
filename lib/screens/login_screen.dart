import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/account/auth_backend.dart';
import '../core/theme.dart';
import '../widgets/account_widgets.dart';
import '../widgets/animated_background.dart';
import '../widgets/bouncy_button.dart';
import 'home_screen.dart';
import 'splash_screen.dart';

enum _Step { choose, phone, code, setup }

const countryCodes = [
  ('🇸🇦', 'السعودية', '+966'),
  ('🇦🇪', 'الإمارات', '+971'),
  ('🇰🇼', 'الكويت', '+965'),
  ('🇶🇦', 'قطر', '+974'),
  ('🇧🇭', 'البحرين', '+973'),
  ('🇴🇲', 'عُمان', '+968'),
  ('🇪🇬', 'مصر', '+20'),
  ('🇯🇴', 'الأردن', '+962'),
  ('🇲🇦', 'المغرب', '+212'),
  ('🇮🇶', 'العراق', '+964'),
];

/// تسجيل الدخول: جوجل، رقم الهاتف برمز تحقق، أو ضيف. ثم اختيار الاسم والصورة.
/// [link] = true يربط حساب الضيف الحالي بدل إنشاء حساب جديد.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.link = false});
  final bool link;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _Step _step = _Step.choose;
  bool _busy = false;
  String? _error;

  int _country = 0;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  int _avatar = 0;
  String get _fullPhone =>
      '${countryCodes[_country].$3}${_phone.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '')}';

  AuthMethod _method = AuthMethod.guest;
  String? _contact;
  String? _uid;

  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on AuthError catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'تعذر الاتصال، حاول مرة أخرى';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _google() => _run(() async {
    final id = await authBackend.signInWithGoogle();
    _method = AuthMethod.google;
    _contact = id.contact;
    _uid = id.uid;
    _name.text = id.name;
    await _afterIdentity();
  });

  void _sendCode() => _run(() async {
    await authBackend.sendPhoneCode(_fullPhone);
    _code.clear();
    _startResend();
    setState(() => _step = _Step.code);
  });

  void _startResend() {
    _resendTimer?.cancel();
    _resendIn = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _verify() => _run(() async {
    final id = await authBackend.verifyPhoneCode(_fullPhone, _code.text);
    _method = AuthMethod.phone;
    _contact = id.contact;
    _uid = id.uid;
    _name.text = id.name;
    await _afterIdentity();
  });

  Future<void> _afterIdentity() async {
    if (widget.link) {
      await Account.instance.link(method: _method, contact: _contact);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() => _step = _Step.setup);
  }

  void _guest() {
    _method = AuthMethod.guest;
    _contact = null;
    _uid = null;
    _name.text = '';
    setState(() => _step = _Step.setup);
  }

  Future<void> _finish() async {
    await Account.instance.signIn(
      method: _method,
      name: _name.text,
      contact: _contact,
      id: _uid,
    );
    await Account.instance.setAvatar(_avatar);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _back() {
    setState(() {
      _error = null;
      _step = switch (_step) {
        _Step.code => _Step.phone,
        _ => _Step.choose,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        if (_step != _Step.choose || widget.link)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => _step == _Step.choose
                                ? Navigator.pop(context)
                                : _back(),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(.08, 0),
                              end: Offset.zero,
                            ).animate(a),
                            child: c,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _body(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_step) {
    _Step.choose => _chooseStep(),
    _Step.phone => _phoneStep(),
    _Step.code => _codeStep(),
    _Step.setup => _setupStep(),
  };

  Widget _title(String t, String sub) => Column(
    children: [
      Text(
        t,
        textAlign: TextAlign.center,
        style: AppTheme.display.copyWith(fontSize: 32),
      ),
      const SizedBox(height: 6),
      Text(
        sub,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _errorText() => _error == null
      ? const SizedBox(height: 8)
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            _error!,
            key: const ValueKey('auth-error'),
            style: const TextStyle(
              color: Color(0xFFFF8A8A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ).animate().shakeX(hz: 4, amount: 4);

  Widget _demoNote() => authBackend.isDemo
      ? Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
          ),
          child: const Text(
            'وضع التجربة: الدخول الحقيقي بجوجل والرسائل يعمل بعد ربط Firebase. رمز التحقق الآن 000000.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        )
      : const SizedBox.shrink();

  Widget _chooseStep() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const MojanLogoMark(size: 110).animate().scale(
          duration: 700.ms,
          curve: Curves.elasticOut,
          begin: const Offset(.5, .5),
        ),
        const SizedBox(height: 14),
        _title(
          widget.link ? 'اربط حسابك' : 'أهلاً بك في MOJAN',
          widget.link
              ? 'احفظ تقدمك وعملاتك على حسابك'
              : 'سجّل دخولك لتحفظ تقدمك وتنافس أصحابك',
        ),
        _AuthButton(
          key: const ValueKey('login-google'),
          label: 'المتابعة باستخدام Google',
          background: Colors.white,
          foreground: const Color(0xFF1F1F1F),
          icon: const _GoogleG(),
          busy: _busy,
          onTap: _google,
        ).animate().fadeIn(delay: 150.ms).slideY(begin: .4, end: 0),
        const SizedBox(height: 12),
        _AuthButton(
          key: const ValueKey('login-phone'),
          label: 'الدخول برقم الهاتف',
          background: AppColors.seeko,
          foreground: AppColors.bgTop,
          icon: const Icon(Icons.phone_iphone_rounded, color: AppColors.bgTop),
          onTap: () => setState(() {
            _error = null;
            _step = _Step.phone;
          }),
        ).animate().fadeIn(delay: 250.ms).slideY(begin: .4, end: 0),
        if (!widget.link) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('أو', style: TextStyle(color: AppColors.textMuted)),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .2)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextButton(
            key: const ValueKey('login-guest'),
            onPressed: _guest,
            child: const Text(
              'العب كضيف',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
        _errorText(),
        _demoNote(),
      ],
    );
  }

  Widget _phoneStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.sms_rounded, size: 64, color: AppColors.seeko),
        const SizedBox(height: 12),
        _title('رقم هاتفك', 'نرسل لك رمز تحقق من 6 أرقام'),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _country,
                    dropdownColor: AppColors.surface,
                    items: [
                      for (final (i, (flag, _, code)) in countryCodes.indexed)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '$flag $code',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _country = v ?? 0),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('phone-field'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                  decoration: _fieldDecoration('5X XXX XXXX'),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendCode(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          countryCodes[_country].$2,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        _errorText(),
        _PrimaryButton(
          key: const ValueKey('send-code'),
          label: 'أرسل الرمز',
          busy: _busy,
          enabled: isValidPhone(_fullPhone),
          onTap: _sendCode,
        ),
        _demoNote(),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.lock_open_rounded, size: 64, color: AppColors.gold),
        const SizedBox(height: 12),
        _title('رمز التحقق', 'أدخل الرمز المرسل إلى'),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            _fullPhone,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
        const SizedBox(height: 18),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            key: const ValueKey('code-field'),
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 14,
            ),
            decoration: _fieldDecoration('------'),
            onChanged: (v) {
              setState(() {});
              if (v.length == 6) _verify();
            },
          ),
        ),
        _errorText(),
        _PrimaryButton(
          key: const ValueKey('verify-code'),
          label: 'تأكيد',
          busy: _busy,
          enabled: _code.text.length == 6,
          onTap: _verify,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resendIn > 0 || _busy ? null : _sendCode,
          child: Text(
            _resendIn > 0
                ? 'إعادة الإرسال بعد $_resendIn ث'
                : 'أعد إرسال الرمز',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        _demoNote(),
      ],
    );
  }

  Widget _setupStep() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _title('اختر اسمك وصورتك', 'يظهران لأصحابك وفي لوحة المتصدرين'),
        PlayerAvatar(index: _avatar, size: 110)
            .animate(key: ValueKey(_avatar))
            .scale(
              duration: 400.ms,
              curve: Curves.elasticOut,
              begin: const Offset(.7, .7),
            ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < avatars.length; i++)
              GestureDetector(
                key: ValueKey('avatar-$i'),
                onTap: () => setState(() => _avatar = i),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: i == _avatar ? 1 : .55,
                  child: PlayerAvatar(index: i, size: 46, ring: i == _avatar),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('name-field'),
          controller: _name,
          maxLength: 18,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          decoration: _fieldDecoration('اسمك في اللعبة')
              .copyWith(counterText: ''),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          key: const ValueKey('finish-setup'),
          label: 'يلا نلعب!',
          enabled: _name.text.trim().isNotEmpty,
          onTap: _finish,
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: .3)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: .1),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.gold, width: 2),
    ),
  );
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });
  final String label;
  final Color background;
  final Color foreground;
  final Widget icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => BouncyButton(
    tilt: false,
    onTap: busy ? () {} : onTap,
    child: Container(
      height: 58,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(background, Colors.black, .5)!,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 26, height: 26, child: icon),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: enabled ? 1 : .45,
    child: BouncyButton(
      tilt: false,
      onTap: enabled && !busy ? onTap : () {},
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD86B), AppColors.goldDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0xFFB36A00), offset: Offset(0, 5)),
          ],
        ),
        child: busy
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.bgTop,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: AppColors.bgTop,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
      ),
    ),
  );
}

/// شعار G بألوان جوجل مرسوم بالكود.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GPainter());
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromLTWH(s * .12, s * .12, s * .76, s * .76);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .17;
    const segs = [
      (Color(0xFF4285F4), -0.25, 0.75),
      (Color(0xFF34A853), 0.5, 1.6),
      (Color(0xFFFBBC05), 2.1, 0.9),
      (Color(0xFFEA4335), 3.0, 1.75),
    ];
    for (final (c, start, sweep) in segs) {
      canvas.drawArc(rect, start, sweep, false, p..color = c);
    }
    canvas.drawLine(
      Offset(s * .5, s * .5),
      Offset(s * .88, s * .5),
      p..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
