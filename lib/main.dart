import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/account/account.dart';
import 'core/ai/ai_brain.dart';
import 'core/ai/speech.dart';
import 'core/ban.dart';
import 'core/firebase/cloud.dart';
import 'core/screenshot.dart';
import 'core/sfx.dart';
import 'core/update_check.dart';
import 'core/rounds/shared_rounds.dart';
import 'core/theme.dart';
import 'core/voice/voice.dart';
import 'screens/vip_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/voice/mini_room_bubble.dart';

Future<void> main() async {
  LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(
        ['Noto Emoji Animation'],
        'Animated gifts in voice rooms use Noto Emoji Animation by Google, licensed under CC BY 4.0 '
        '(https://creativecommons.org/licenses/by/4.0/). Resized for the app.',
      )));
  WidgetsFlutterBinding.ensureInitialized();
  await Account.instance.load();
  Speech.natural = (t, v, eg) => AiBrain.instance.tts(t, v, egyptian: eg);
  // تشغيل Firebase والربط بالسيرفر في الخلفية حتى لا يتأخر فتح التطبيق
  unawaited(Cloud.instance.init().then((_) => Account.instance.attachCloud()));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  UpdateCheck.instance.start();
  SharedClock.sync();
  Account.instance.onChairChanged = VoiceService.instance.applyMyChair;
  runApp(const MojanApp());
}

class MojanApp extends StatelessWidget {
  const MojanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOJAN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorKey: appNavigatorKey,
      // فقاعة الغرفة الصوتية المصغّرة تطفو فوق كل الشاشات
      builder: (context, child) =>
          Stack(children: [
            // صوت نقر خفيف مع كل لمسة (يتوقف من الإعدادات)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => Sfx.instance.tap(),
              child: RepaintBoundary(key: appShotKey, child: child ?? const SizedBox.shrink()),
            ),
            const MiniRoomBubble(),
            // نسخة جديدة نزلت: زر تحديث صغير فوق
            ValueListenableBuilder<bool>(
              valueListenable: UpdateCheck.instance.available,
              builder: (_, has, _) => !has
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6),
                        child: Material(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            key: const ValueKey('update-banner'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: UpdateCheck.instance.reload,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text('✨ فيه تحديث جديد، اضغط للتحديث',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // إشعار الإدارة (مثل وصول عملات الشحن)
            ValueListenableBuilder<String?>(
              valueListenable: Cloud.instance.notice,
              builder: (_, text, _) => text == null ? const SizedBox.shrink() : _AdminNotice(text: text),
            ),
            const VipUpOverlay(),
            ValueListenableBuilder<bool>(
              valueListenable: Restrictions.instance.fullBan,
              builder: (_, banned, _) => banned
                  ? ColoredBox(
                      color: const Color(0xF0120A26),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                              'تم إيقاف حسابك من الإدارة 🚫\n'
                              '${Restrictions.instance.current.value?.until == null ? 'الإيقاف دائم' : 'ينتهي الإيقاف ${Restrictions.instance.current.value!.remaining().replaceFirst('باقي', 'بعد')}'}'
                              '${(Restrictions.instance.current.value?.reason ?? '').isEmpty ? '' : '\nالسبب: ${Restrictions.instance.current.value!.reason}'}'
                              '\nللاستفسار تواصل مع إدارة MOJAN.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.none, height: 1.6)),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
      home: const SplashScreen(),
    );
  }
}

/// بطاقة إشعار من إدارة MOJAN فوق كل الشاشات.
class _AdminNotice extends StatelessWidget {
  const _AdminNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          key: const ValueKey('admin-notice'),
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .35), blurRadius: 30)],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/images/brand_icon.webp', width: 56, height: 56),
              ),
              const SizedBox(height: 8),
              const Text('رسالة من إدارة MOJAN',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 10),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1.5)),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('admin-notice-ok'),
                onPressed: () => Cloud.instance.notice.value = null,
                child: const Text('تمام 👍'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
