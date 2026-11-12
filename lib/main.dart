import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/account/account.dart';
import 'core/ai/ai_brain.dart';
import 'core/ai/speech.dart';
import 'core/firebase/cloud.dart';
import 'core/screenshot.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/voice/mini_room_bubble.dart';

Future<void> main() async {
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
            RepaintBoundary(key: appShotKey, child: child ?? const SizedBox.shrink()),
            const MiniRoomBubble(),
            // إشعار الإدارة (مثل وصول عملات الشحن)
            ValueListenableBuilder<String?>(
              valueListenable: Cloud.instance.notice,
              builder: (_, text, _) => text == null ? const SizedBox.shrink() : _AdminNotice(text: text),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: Cloud.instance.banned,
              builder: (_, banned, _) => banned
                  ? const ColoredBox(
                      color: Color(0xF0120A26),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('تم إيقاف حسابك من الإدارة 🚫\nللاستفسار تواصل مع إدارة MOJAN.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
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
