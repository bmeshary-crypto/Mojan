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
    this.dialect = 'السعودية البيضاء',
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

  /// اللهجة التي تتكلم بها الشخصية (سعودية أو مصرية).
  final String dialect;

  bool get egyptian => dialect.contains('المصرية');
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
  AiPersona(
    id: 'ai-mona',
    name: 'منى',
    avatar: 4,
    female: true,
    style: 'بنت مصرية دمها خفيف وبتحب الهزار والقفشات، بتتكلم بعفوية وبترحب بالناس',
    bio: 'ذكاء اصطناعي 🤖 من مصر وبحب الضحك',
    voice: 'Kore',
    dialect: 'المصرية',
    fallback: ['أهلاً أهلاً نورتوا 🌹', 'إيه الأخبار يا جماعة؟', 'هههه والله إنتوا عسل', 'كمل كمل أنا سامعاك 👂', 'حلو أوي الموضوع ده!'],
  ),
  AiPersona(
    id: 'ai-karim',
    name: 'كريم',
    avatar: 7,
    female: false,
    style: 'شاب مصري جدع وابن نكتة، بيحب الكورة والألعاب والتحديات، ردوده قصيرة',
    bio: 'ذكاء اصطناعي 🤖 من مصر، تعالى نلعب',
    voice: 'Fenrir',
    dialect: 'المصرية',
    fallback: ['يا أهلاً يا أهلاً', 'مين يلاعبني لودو؟ 🎲', 'كلام جميل والله', 'عندك حق', 'أنا معاكم أهو 😄'],
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

  /// الصوت الطبيعي متاح (ليس في فترة راحة بعد تجاوز الحصة).
  bool get ttsAvailable => override == null && Cloud.instance.enabled && !_ttsCooldown;

  /// انتهت حصة الصوت الطبيعي مؤقتاً.
  bool get ttsDown => override == null && Cloud.instance.enabled && _ttsCooldown;

  bool get online => override != null || (Cloud.instance.enabled && !_cooldown);

  /// رد شخصية على محادثة. [about] وصف المكان (غرفة صوتية، لعبة صراحة...).
  Future<String> reply(AiPersona p, {required String about, List<AiLine> history = const [], String? ask, int maxWords = 25, int maxTokens = 120}) async {
    final system = 'أنت "${p.name}"، شخصية ذكاء اصطناعي داخل تطبيق الألعاب الاجتماعي MOJAN. '
        'شخصيتك: ${p.style}. المكان: $about. '
        'تكلم باللهجة ${p.dialect} وبجمل قصيرة جداً (حد أقصى $maxWords كلمة)، كأنك تتكلم في الدردشة. '
        'كن محترماً ولطيفاً ومناسباً لكل الأعمار، لا تطلب معلومات شخصية أو فلوس، ولا تدّعِ أنك إنسان إذا سُئلت. '
        'لا تكتب اسمك في بداية الرد ولا تستخدم علامات اقتباس.';
    final lines = history.length > 12 ? history.sublist(history.length - 12) : history;
    final prompt = [
      if (lines.isNotEmpty) 'آخر المحادثة:\n${lines.map((l) => '${l.name}: ${l.text}').join('\n')}',
      ask ?? 'اكتب ردك الآن على آخر رسالة.',
    ].join('\n\n');
    final text = await _generate(system, prompt, maxTokens: maxTokens);
    return _clean(text, p, maxTokens > 120 ? 420 : 220) ?? p.fallback[_rng.nextInt(p.fallback.length)];
  }

  /// طلب حر (مثل إجابة سؤال صراحة) بنفس الشخصية.
  Future<String> say(AiPersona p, {required String about, required String ask, int maxWords = 30, int maxTokens = 120}) =>
      reply(p, about: about, ask: ask, maxWords: maxWords, maxTokens: maxTokens);

  /// نص طويل بصيغة JSON (مثل حلقة بودكاست). يرجع null عند الفشل.
  Future<String?> json(String system, String prompt, {int maxTokens = 2500}) => _generate(system, prompt, maxTokens: maxTokens, json: true);

  Future<String?> _generate(String system, String prompt, {int maxTokens = 120, bool json = false}) async {
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
        generationConfig: GenerationConfig(maxOutputTokens: maxTokens, temperature: .9, responseMimeType: json ? 'application/json' : null),
      );
      final res = await m.generateContent([Content.text(prompt)]).timeout(Duration(seconds: json ? 60 : 15));
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
  Future<Uint8List?> tts(String text, String voice, {bool egyptian = false}) async {
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
      final who = egyptian
          ? 'A friendly young Egyptian host chatting in a relaxed podcast, natural Egyptian Arabic (Cairo) accent.'
          : 'A friendly young Saudi host chatting in a relaxed podcast, natural Saudi Arabic dialect.';
      final prompt = '# Audio profile\n$who\n'
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
      // انتهاء الحصة اليومية يحتاج راحة أطول من خطأ عابر
      final quota = '$e'.contains('quota') || '$e'.contains('429');
      Timer(Duration(minutes: quota ? 20 : 2), () => _ttsCooldown = false);
    }
    return null;
  }

  String? _clean(String? t, AiPersona p, [int max = 220]) {
    if (t == null) return null;
    var s = t.trim().replaceAll('"', '').replaceAll('*', '');
    if (s.startsWith('${p.name}:')) s = s.substring(p.name.length + 1).trim();
    if (s.isEmpty) return null;
    return s.length > max ? '${s.substring(0, max - 3)}…' : s;
  }
}
