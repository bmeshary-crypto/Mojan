import 'dart:async';
import 'dart:math';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../firebase/cloud.dart';

/// شخصية ذكاء اصطناعي تظهر في الغرف والألعاب. تحمل شارة AI دائماً حتى لا يظنها أحد إنساناً.
class AiPersona {
  const AiPersona({
    required this.id,
    required this.name,
    required this.avatar,
    required this.female,
    required this.style,
    required this.bio,
    required this.fallback,
    this.voice = 'Aoede',
  });
  final String id;
  final String name;
  final int avatar;
  final bool female;

  /// وصف الشخصية الذي يُرسل للنموذج.
  final String style;
  final String bio;

  /// ردود جاهزة عند انقطاع الذكاء الاصطناعي.
  final List<String> fallback;

  /// صوت Gemini الطبيعي (نفس أصوات NotebookLM).
  final String voice;
}

const aiPersonas = [
  AiPersona(
    id: 'ai-noura',
    name: 'نورة',
    avatar: 2,
    female: true,
    style: 'بنت سعودية مرحة واجتماعية، تحب السوالف والضحك وترحب بالناس، تستخدم إيموجي قليل',
    bio: 'مساعدة MOJAN الذكية 🤖 أسولف وأرحب فيكم',
    voice: 'Aoede',
    fallback: ['هلا والله نورتونا 🌹', 'وش أخباركم الليلة؟', 'هههه والله إنكم فلة', 'كمل كمل أسمعك 👂', 'حلو هالموضوع!'],
  ),
  AiPersona(
    id: 'ai-sultan',
    name: 'سلطان',
    avatar: 5,
    female: false,
    style: 'شاب سعودي هادئ وذكي، يحب الألعاب والتحديات والنكت الخفيفة، يعطي آراء قصيرة',
    bio: 'ذكاء اصطناعي 🤖 أحب اللودو والتحديات',
    voice: 'Puck',
    fallback: ['يا هلا ومرحبا', 'من يتحداني لودو؟ 🎲', 'كلام جميل والله', 'صح كلامك', 'تراني معكم أسمع 😄'],
  ),
  AiPersona(
    id: 'ai-reem',
    name: 'ريم',
    avatar: 16,
    female: true,
    style: 'بنت خليجية لطيفة تحب الأسئلة والمعلومات العامة والأغاني، تسأل الناس عن آرائهم',
    bio: 'ذكاء اصطناعي 🤖 أحب الأسئلة والمعلومات',
    voice: 'Leda',
    fallback: ['سؤال: وش أكثر لعبة تحبونها؟', 'تدرون إن العسل ما يخرب أبداً؟ 🍯', 'منورين 🌸', 'أحب هالجو ✨'],
  ),
];

AiPersona? personaById(String id) => aiPersonas.where((p) => p.id == id).firstOrNull;

/// سطر من المحادثة يُرسل كسياق.
class AiLine {
  const AiLine(this.name, this.text);
  final String name;
  final String text;
}

/// العقل: يرسل للنموذج Gemini عبر Firebase AI Logic (مجاني ومحمي بـ App Check).
/// عند عدم توفره (وضع التجربة، تجاوز الحد) يرد بردود جاهزة.
class AiBrain {
  AiBrain._();
  static final instance = AiBrain._();

  static const model = 'gemini-3.5-flash-lite';
  static const ttsModel = 'gemini-3.1-flash-tts-preview';
  bool _ttsCooldown = false;
  final _ttsCache = <String, Uint8List>{};
  final _rng = Random();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _cooldown = false;

  /// للاختبارات: استبدال الاتصال بالنموذج.
  @visibleForTesting
  Future<String?> Function(String system, String prompt)? override;

  bool get online => override != null || (Cloud.instance.enabled && !_cooldown);

  /// رد شخصية على محادثة. [about] وصف المكان (غرفة صوتية، لعبة صراحة...).
  Future<String> reply(AiPersona p, {required String about, List<AiLine> history = const [], String? ask, int maxWords = 25}) async {
    final system = 'أنت "${p.name}"، شخصية ذكاء اصطناعي داخل تطبيق الألعاب الاجتماعي MOJAN. '
        'شخصيتك: ${p.style}. المكان: $about. '
        'تكلم باللهجة السعودية البيضاء وبجمل قصيرة جداً (حد أقصى $maxWords كلمة)، كأنك تتكلم في الدردشة. '
        'كن محترماً ولطيفاً ومناسباً لكل الأعمار، لا تطلب معلومات شخصية أو فلوس، ولا تدّعِ أنك إنسان إذا سُئلت. '
        'لا تكتب اسمك في بداية الرد ولا تستخدم علامات اقتباس.';
    final lines = history.length > 12 ? history.sublist(history.length - 12) : history;
    final prompt = [
      if (lines.isNotEmpty) 'آخر المحادثة:\n${lines.map((l) => '${l.name}: ${l.text}').join('\n')}',
      ask ?? 'اكتب ردك الآن على آخر رسالة.',
    ].join('\n\n');
    final text = await _generate(system, prompt);
    return _clean(text, p) ?? p.fallback[_rng.nextInt(p.fallback.length)];
  }

  /// طلب حر (مثل إجابة سؤال صراحة) بنفس الشخصية.
  Future<String> say(AiPersona p, {required String about, required String ask, int maxWords = 30}) =>
      reply(p, about: about, ask: ask, maxWords: maxWords);

  Future<String?> _generate(String system, String prompt) async {
    if (override != null) return override!(system, prompt);
    if (!online) return null;
    // حماية الحصة المجانية: طلب واحد كل 4 ثوانٍ على الأكثر من هذا الجهاز
    final wait = const Duration(seconds: 4) - DateTime.now().difference(_last);
    if (wait > Duration.zero) await Future.delayed(wait);
    _last = DateTime.now();
    try {
      final m = FirebaseAI.googleAI().generativeModel(
        model: model,
        systemInstruction: Content.system(system),
        generationConfig: GenerationConfig(maxOutputTokens: 120, temperature: .9),
      );
      final res = await m.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 15));
      return res.text;
    } catch (e) {
      debugPrint('AiBrain failed: $e');
      // عند تجاوز الحد نرتاح دقيقة ونستخدم الردود الجاهزة
      _cooldown = true;
      Timer(const Duration(seconds: 60), () => _cooldown = false);
      return null;
    }
  }

  /// صوت طبيعي من Gemini TTS: PCM خام 24kHz أحادي 16bit. يرجع null عند الفشل (ونستخدم صوت المتصفح).
  Future<Uint8List?> tts(String text, String voice) async {
    if (override != null || !Cloud.instance.enabled || _ttsCooldown) return null;
    final key = '$voice|$text';
    final hit = _ttsCache[key];
    if (hit != null) return hit;
    try {
      final m = FirebaseAI.googleAI().generativeModel(
        model: ttsModel,
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.audio],
          speechConfig: SpeechConfig(voiceName: voice),
        ),
      );
      final prompt = '# Audio profile\nA friendly young Saudi host chatting in a relaxed podcast, natural Saudi Arabic dialect.\n'
          '# Director\'s notes\nWarm, clear, expressive and natural, normal conversational pace. Read only the transcript.\n'
          '# Transcript\n$text';
      for (var attempt = 0; attempt < 2; attempt++) {
        final res = await m.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 20));
        final parts = res.candidates.firstOrNull?.content.parts ?? const [];
        for (final part in parts) {
          if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
            if (_ttsCache.length > 40) _ttsCache.remove(_ttsCache.keys.first);
            return _ttsCache[key] = part.bytes;
          }
        }
      }
    } catch (e) {
      debugPrint('AiBrain tts failed: $e');
      // عند تجاوز الحد المجاني نرجع لصوت المتصفح دقيقتين
      _ttsCooldown = true;
      Timer(const Duration(minutes: 2), () => _ttsCooldown = false);
    }
    return null;
  }

  String? _clean(String? t, AiPersona p) {
    if (t == null) return null;
    var s = t.trim().replaceAll('"', '').replaceAll('*', '');
    if (s.startsWith('${p.name}:')) s = s.substring(p.name.length + 1).trim();
    if (s.isEmpty) return null;
    return s.length > 220 ? '${s.substring(0, 217)}…' : s;
  }
}
