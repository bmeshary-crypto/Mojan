import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/ai/ai_brain.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    VoiceService.instance.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  tearDown(() => AiBrain.instance.override = null);

  test('AI persona in a voice room answers what the user writes', () async {
    String? system, prompt;
    AiBrain.instance.override = (s, p) async {
      system = s;
      prompt = p;
      return 'نورة: هلا موكا، نورت الغرفة 🌹';
    };
    final svc = VoiceService.instance;
    final r = svc.create(title: 'سهرة', category: VoiceCategory.chat);
    expect(svc.aiOnMics(r).single.name, contains('نورة'));
    svc.sendMessage(r, 'هلا نورة كيفك؟');
    await Future.delayed(const Duration(seconds: 3));
    final reply = r.messages.lastWhere((m) => m.user?.isAi == true);
    expect(reply.text, 'هلا موكا، نورت الغرفة 🌹', reason: 'name prefix is stripped');
    expect(system, contains('نورة'));
    expect(prompt, contains('هلا نورة كيفك؟'));
  });

  test('without the model, personas fall back to ready replies', () async {
    final p = aiPersonas.first;
    final text = await AiBrain.instance.reply(p, about: 'test');
    expect(p.fallback, contains(text));
  });
}
