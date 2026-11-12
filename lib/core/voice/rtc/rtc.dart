// الصوت الحقيقي بين المتصفحات (WebRTC). خارج الويب يوجد بديل صامت.
export 'rtc_stub.dart' if (dart.library.js_interop) 'rtc_web.dart';
