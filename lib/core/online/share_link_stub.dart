/// رابط الموقع الأساسي لدعوات الغرف.
String siteUrl() => 'https://bmeshary-crypto.github.io/Mojan/';

/// يمسح ?join من الرابط بعد قراءته (على الويب فقط).
void clearJoinParam() {}

/// مشاركة عبر قائمة المشاركة في الجوال. يرجع false إذا ما كانت متاحة.
Future<bool> shareNative(String text) async => false;

void openExternal(String url) {}
