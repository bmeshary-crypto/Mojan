import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/account/account.dart';
import 'core/firebase/cloud.dart';
import 'core/screenshot.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/voice/mini_room_bubble.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Account.instance.load();
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
