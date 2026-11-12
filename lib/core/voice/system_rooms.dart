import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../ai/ai_brain.dart';
import '../ai/speech.dart';
import '../firebase/cloud.dart';
import '../rounds/shared_rounds.dart';
import 'live_voice.dart';
import 'podcast_content.dart';
import 'voice.dart';

/// غرفتا النظام الثابتتان، وهما المكان الوحيد الذي تتكلم فيه شخصيات الذكاء الاصطناعي:
/// - «الترحيب بالأعضاء الجدد»: نورة ترحب بكل من يدخل باسمه وبشعر سعودي، ومنى تقول له كلمة مصرية حلوة.
/// - «بودكاست موجان»: سلطان وريم يتحاوران (رأي ورأي آخر) في مواضيع اليوم، والمايكات لهم فقط،
///   ومن يكتب في الدردشة يُرد عليه كتابةً في التعليقات.
class SystemRooms {
  SystemRooms._();
  static final instance = SystemRooms._();

  static const welcomeId = 'sys_welcome';
  static const podcastId = 'sys_podcast';

  static AiPersona get welcomeHost => personaById('ai-noura')!;
  static AiPersona get welcomeEgypt => personaById('ai-mona')!;
  static AiPersona get podA => personaById('ai-sultan')!;
  static AiPersona get podB => personaById('ai-reem')!;

  VoiceService get _svc => VoiceService.instance;
  final _rng = Random();

  // ---------- بناء الغرف ----------

  List<VoiceRoom> build() => [_welcome(), _podcast()];

  VoiceRoom _welcome() {
    final r = VoiceRoom(
      id: welcomeId,
      title: 'الترحيب بالأعضاء الجدد 🌹',
      host: _svc.aiUser(welcomeHost),
      category: VoiceCategory.chat,
      seats: 8,
      theme: VoiceTheme.party,
      announcement: 'أهلاً بكل عضو جديد! نورة ومنى يرحبون فيك، اطلع على المايك أو اكتب وسولف معهم 🌹',
      heat: 0,
    )..system = 'welcome';
    pin(r);
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: r.announcement));
    return r;
  }

  VoiceRoom _podcast() {
    final r = VoiceRoom(
      id: podcastId,
      title: 'بودكاست موجان 🎙️',
      host: _svc.aiUser(podA),
      category: VoiceCategory.chat,
      seats: 4,
      announcement: '🎙️ بودكاست موجان: رأي ورأي آخر. المايكات للمذيعين فقط، وتقدر تكتب لهم وترسل هدايا',
      heat: 0,
    )..system = 'podcast';
    for (final s in r.seats.skip(1)) {
      s.locked = true;
    }
    pin(r);
    final eps = _fallbackFor(dayOf(SharedClock.nowMs()));
    r.topic = eps.first.topic;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: r.announcement));
    return r;
  }

  /// شخصيات الـ AI في أماكنها الثابتة دائماً.
  void pin(VoiceRoom r) {
    if (r.isWelcome) {
      if (r.seats[0].user?.aiId != welcomeEgypt.id) r.seats[0].user = _svc.aiUser(welcomeEgypt);
    } else if (r.isPodcast) {
      if (r.seats[0].user?.aiId != podB.id) r.seats[0].user = _svc.aiUser(podB);
      for (final s in r.seats.skip(1)) {
        s.user = null;
        s.locked = true;
      }
    }
  }

  /// المقاعد الثابتة لشخصيات الـ AI (تُحفظ في السيرفر حتى لا يجلس عليها أحد).
  Map<String, dynamic> aiSeats(VoiceRoom r) => {
        if (r.isWelcome) '0': {'ai': welcomeEgypt.id},
        if (r.isPodcast) '0': {'ai': podB.id},
      };

  // ---------- الدخول والخروج ----------

  VoiceRoom? _pod;

  void entered(VoiceRoom r) {
    if (r.isWelcome) unawaited(_greet(r));
    if (r.isPodcast) _startPodcast(r);
  }

  void left(VoiceRoom r) {
    if (r.isPodcast && _pod == r) _stopPodcast();
  }

  /// كلام شخصية AI في الغرفة. [quiet] = كتابة فقط في التعليقات بدون صوت.
  Future<void> _say(VoiceRoom r, AiPersona p, String text, {bool quiet = false}) async {
    if (r.live) {
      await LiveVoice.instance.postAi(r, p, text, quiet: quiet);
      return;
    }
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: text, user: _svc.aiUser(p)));
    if (!quiet) {
      if (_svc.speakerOn) Speech.instance.speak(text, female: p.female, voice: p.voice, egyptian: p.egyptian, naturalOnly: r.isWelcome);
      glow(r, p.id, text);
    }
    _svc.notify();
  }

  /// حلقة المتحدث تضيء بقدر طول الكلام تقريباً.
  void glow(VoiceRoom r, String aiId, String text) {
    final users = [r.host, for (final s in r.seats) ?s.user].where((u) => u.aiId == aiId);
    for (final u in users) {
      u.speaking = true;
    }
    if (r.host.aiId == aiId) r.hostSpeaking = true;
    _svc.notify();
    Future.delayed(Duration(milliseconds: 1200 + text.length * 80), () {
      for (final u in users) {
        u.speaking = false;
      }
      if (r.host.aiId == aiId) r.hostSpeaking = false;
      _svc.notify();
    });
  }

  // ---------- غرفة الترحيب ----------

  final _greeted = <String, DateTime>{};

  Future<void> _greet(VoiceRoom r) async {
    final me = _svc.me();
    final last = _greeted[me.id];
    if (last != null && DateTime.now().difference(last).inMinutes < 10) return;
    _greeted[me.id] = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (r.closed) return;
    final name = me.name;
    const about = 'غرفة "الترحيب بالأعضاء الجدد" في MOJAN، وأنت من مستضيفي الغرفة وترحب بكل عضو يدخل';
    final ai = AiBrain.instance;
    final poem = ai.online
        ? await ai.say(
            welcomeHost,
            about: about,
            ask: 'دخل الغرفة الآن عضو اسمه "$name". رحبي فيه باسمه ترحيب حار، ثم قولي له بيتين من الشعر النبطي السعودي '
                'القصير الجميل في الترحيب به، وخلي اسمه في الشعر إن أمكن. لا تزيدي عن 40 كلمة.',
            maxWords: 40,
            maxTokens: 400,
          )
        : _poem(name);
    await _say(r, welcomeHost, poem);
    await Future.delayed(Duration(milliseconds: 2500 + poem.length * 60));
    if (r.closed) return;
    final eg = ai.online
        ? await ai.say(
            welcomeEgypt,
            about: about,
            ask: 'عضو جديد اسمه "$name" دخل الغرفة ورحبت به نورة بالشعر. قولي له جملة ترحيب مصرية حلوة وخفيفة دم باسمه.',
            maxWords: 20,
            maxTokens: 200,
          )
        : _egypt(name);
    await _say(r, welcomeEgypt, eg);
  }

  String _poem(String n) => [
        'يا هلا يا $n نورت المكان 🌹\nيا هلا باللي حضوره زاد الغرفة جمال\nمرحبا عدّ المطر لا هلّ وبان',
        'هلا والله يا $n حياك 🌹\nيا مرحبا ترحيبةٍ ما تنحصي\nيا هلا باللي لفانا وطاب ممشاه',
        'أهلاً وسهلاً يا $n في MOJAN 🌹\nحيّ الضيف اللي لفانا\nبالطيب والضحكة نلقاه',
      ][_rng.nextInt(3)];

  String _egypt(String n) => [
        'يا أهلاً يا أهلاً يا $n! نورت الدنيا كلها والله 🌸',
        'إيه النور ده يا $n! اعتبر نفسك في بيتك يا جميل 😄',
        'أهلاً بيك يا $n، ده إحنا زارنا النبي، نورتنا يا عسل 🌹',
      ][_rng.nextInt(3)];

  // ---------- الدردشة والهدايا (يشغّلها جهاز كاتب الرسالة فقط) ----------

  Future<void> onMyChat(VoiceRoom r, String text) async {
    if (r.isWelcome) {
      await _svc.aiRespond(r, text);
      return;
    }
    if (!r.isPodcast) return;
    final addressed = [podA, podB].where((p) => text.contains(p.name)).toList();
    final p = addressed.isNotEmpty ? addressed.first : (_rng.nextBool() ? podA : podB);
    final me = _svc.me();
    final history = [
      for (final m in r.messages.where((m) => m.kind == VoiceMsgKind.chat && m.user != null).toList().reversed.take(8).toList().reversed)
        AiLine(m.user!.name, m.text),
    ];
    final reply = await AiBrain.instance.reply(
      p,
      about: 'بودكاست موجان، وأنت أحد المذيعين، وموضوع الحلقة الآن "${r.topic ?? 'مواضيع عامة'}". '
          'مستمع كتب تعليق في الدردشة وأنت ترد عليه كتابة في التعليقات وأنت مشغول بالبودكاست',
      history: history,
      ask: '${me.name} كتب: "$text". رد عليه باسمه رد قصير ولطيف.',
      maxWords: 22,
    );
    await _say(r, p, reply, quiet: true);
  }

  Future<void> onMyGift(VoiceRoom r, VoiceMessage m) async {
    final ais = m.to.where((u) => u.isAi).toList();
    if (ais.isEmpty || m.gift == null) return;
    final p = personaById(ais.first.aiId!);
    if (p == null) return;
    final name = m.user?.name ?? '';
    final thanks = p.egyptian
        ? 'تسلم إيدك يا $name على ${m.gift!.title}! ده إنت جميل أوي 💖'
        : 'تسلم يدك يا $name على ${m.gift!.title}! والله إنك ذوق 💖';
    await Future.delayed(const Duration(milliseconds: 900));
    await _say(r, p, thanks, quiet: r.isPodcast);
  }

  // ---------- البودكاست ----------

  /// اليوم بتوقيت السعودية (المواضيع تتغير منتصف الليل).
  static int dayOf(int ms) => (ms + 3 * 3600000) ~/ 86400000;
  static int dayStart(int day) => day * 86400000 - 3 * 3600000;

  static int lineMs(String t) => 1300 + t.length * 85;
  static const _episodeGap = 3000, _loopGap = 6000;

  List<PodEpisode> _fallbackFor(int day) => [podFallback[day % podFallback.length], podFallback[(day + 1) % podFallback.length]];

  static List<PodTopic> topicsFor(int day) => [podTopics[(2 * day) % podTopics.length], podTopics[(2 * day + 1) % podTopics.length]];

  int _day = -1;
  List<PodEpisode> _episodes = const [];
  final List<({PodEpisode ep, PodLine line, int start, int dur})> _timeline = [];
  int _total = 1;
  Timer? _tick;
  int _cur = -2;
  bool _justStarted = true;
  final Set<int> _genTried = {};

  void _setEpisodes(int day, List<PodEpisode> eps) {
    _day = day;
    _episodes = eps;
    _timeline.clear();
    var t = 0;
    for (final (i, ep) in eps.indexed) {
      if (i > 0) t += _episodeGap;
      for (final l in ep.lines) {
        final d = lineMs(l.text);
        _timeline.add((ep: ep, line: l, start: t, dur: d));
        t += d;
      }
    }
    _total = t + _loopGap;
    _cur = -2;
  }

  /// الحلقة المعروضة الآن (للاختبارات والعرض).
  ({PodEpisode ep, PodLine line, int offset})? podcastAt(int ms) {
    if (_timeline.isEmpty) return null;
    final pos = (ms - dayStart(_day)) % _total;
    for (final e in _timeline) {
      if (pos >= e.start && pos < e.start + e.dur) return (ep: e.ep, line: e.line, offset: pos - e.start);
    }
    return null;
  }

  void _startPodcast(VoiceRoom r) {
    _stopPodcast();
    _pod = r;
    _justStarted = true;
    final day = dayOf(SharedClock.nowMs());
    if (day != _day || _episodes.isEmpty) _setEpisodes(day, _fallbackFor(day));
    _cur = -2;
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _step());
    _step();
  }

  void _stopPodcast() {
    _tick?.cancel();
    _tick = null;
    if (_radioOn) Speech.instance.stopStream();
    _radioOn = false;
    final r = _pod;
    _pod = null;
    if (r != null) _showLine(r, null, null);
  }

  // ---- البث الاحتياطي (بودكاست عربي من الإنترنت) ----
  bool _radioOn = false;
  int _radioIdx = -1;
  int _lastProbe = 0;

  bool get radioOn => _radioOn;

  /// الحلقة والثانية الحالية في البث الاحتياطي (نفسها عند الجميع).
  static ({int index, int offset}) radioAt(int ms) {
    final total = radioItems.fold(0, (a, b) => a + b.seconds);
    var pos = ((ms - dayStart(dayOf(ms))) ~/ 1000) % total;
    for (final (i, it) in radioItems.indexed) {
      if (pos < it.seconds) return (index: i, offset: pos);
      pos -= it.seconds;
    }
    return (index: 0, offset: 0);
  }

  void _radio(VoiceRoom r, int now) {
    if (!_radioOn) {
      _radioOn = true;
      _radioIdx = -1;
      _lastProbe = now;
      Speech.instance.stopSpeaking();
    }
    final at = radioAt(now);
    final it = radioItems[at.index];
    if (_svc.speakerOn && (at.index != _radioIdx || !Speech.instance.streaming)) {
      Speech.instance.playStream(it.url, at.offset.toDouble());
    } else if (!_svc.speakerOn && Speech.instance.streaming) {
      Speech.instance.stopStream();
    }
    if (at.index != _radioIdx || r.caption != '🎧 ${it.title}') {
      _radioIdx = at.index;
      r.topic = 'بث من $radioSource';
      r.caption = '🎧 ${it.title}';
      r.captionBy = null;
      r.host.speaking = false;
      r.hostSpeaking = false;
      r.seats[0].user?.speaking = false;
      _svc.notify();
    }
    // بعد انتهاء فترة الراحة نجرب الصوت الطبيعي بهدوء، ونرجع للمذيعين فقط إذا نجح
    if (!AiBrain.instance.ttsDown && now - _lastProbe > 60000 && _timeline.isNotEmpty) {
      _lastProbe = now;
      final l = _timeline.first.line;
      final p = l.who == 0 ? podA : podB;
      AiBrain.instance.tts(l.text, p.voice, egyptian: p.egyptian).then((d) {
        if (d != null && _radioOn) {
          _radioOn = false;
          Speech.instance.stopStream();
          _cur = -2;
          _justStarted = true;
        }
      });
    }
  }

  void _step() {
    final r = _pod;
    if (r == null) return;
    final now = SharedClock.nowMs();
    final day = dayOf(now);
    if (day != _day) {
      _setEpisodes(day, _fallbackFor(day));
      _maybeGenerate(r, null);
    }
    if (_radioOn || AiBrain.instance.ttsDown) {
      _radio(r, now);
      return;
    }
    final pos = (now - dayStart(_day)) % _total;
    var idx = -1;
    for (final (i, e) in _timeline.indexed) {
      if (pos >= e.start && pos < e.start + e.dur) {
        idx = i;
        break;
      }
    }
    if (idx == _cur) return;
    _cur = idx;
    if (idx < 0) {
      _showLine(r, null, null);
      _justStarted = false;
      return;
    }
    final e = _timeline[idx];
    final p = e.line.who == 0 ? podA : podB;
    _showLine(r, e.ep, e.line);
    final into = pos - e.start;
    // من يدخل في منتصف جملة يرى نصها ويسمع من الجملة التالية
    final speak = !_justStarted || into < 1500;
    _justStarted = false;
    if (speak && _svc.speakerOn && Speech.instance.pending <= 1) {
      // بصوت Gemini الطبيعي فقط؛ إذا انتهت الحصة ننتقل للبث الاحتياطي
      Speech.instance.speak(e.line.text, female: p.female, voice: p.voice, egyptian: p.egyptian, naturalOnly: Cloud.instance.enabled);
    }
    // نجهز صوت الجملة التالية مسبقاً
    final next = _timeline[(idx + 1) % _timeline.length];
    final np = next.line.who == 0 ? podA : podB;
    unawaited(AiBrain.instance.tts(next.line.text, np.voice, egyptian: np.egyptian));
  }

  void _showLine(VoiceRoom r, PodEpisode? ep, PodLine? line) {
    if (ep != null) r.topic = ep.topic;
    r.caption = line?.text;
    r.captionBy = line == null ? null : (line.who == 0 ? r.host : r.seats[0].user);
    r.host.speaking = line?.who == 0;
    r.hostSpeaking = line?.who == 0;
    final b = r.seats[0].user;
    if (b != null) b.speaking = line?.who == 1;
    _svc.notify();
  }

  /// بيانات غرفة البودكاست من السيرفر: حلقة اليوم المولّدة إن وُجدت.
  void onDoc(VoiceRoom r, Map<String, dynamic> data) {
    if (!r.isPodcast) return;
    final pod = data['pod'];
    final day = dayOf(SharedClock.nowMs());
    if (pod is Map && pod['day'] == day) {
      final eps = [for (final e in (pod['episodes'] as List? ?? [])) ?PodEpisode.fromJson(e)];
      if (eps.isNotEmpty && (day != _day || !_same(eps))) {
        _setEpisodes(day, eps);
        if (_pod == r) _step();
      }
      return;
    }
    _maybeGenerate(r, data);
  }

  bool _same(List<PodEpisode> eps) =>
      eps.length == _episodes.length && [for (var i = 0; i < eps.length; i++) eps[i].topic == _episodes[i].topic && eps[i].lines.length == _episodes[i].lines.length].every((x) => x);

  /// أول جهاز يدخل البودكاست في اليوم يكتب حلقتي اليوم بالذكاء الاصطناعي ويحفظهما للجميع.
  Future<void> _maybeGenerate(VoiceRoom r, Map<String, dynamic>? data) async {
    if (!r.live || !AiBrain.instance.online) return;
    final day = dayOf(SharedClock.nowMs());
    if (!_genTried.add(day)) return;
    if (!await LiveVoice.instance.claimPodcast(r, day)) return;
    final eps = await generateEpisodes(day);
    if (eps == null) return;
    await LiveVoice.instance.savePodcast(r, day, [for (final e in eps) e.toJson()]);
  }

  Future<List<PodEpisode>?> generateEpisodes(int day) async {
    final out = <PodEpisode>[];
    for (final (i, t) in topicsFor(day).indexed) {
      final system = 'أنت كاتب بودكاست عربي محترف لتطبيق الألعاب الاجتماعي MOJAN. تكتب حوار قصير وممتع ومحترم '
          'ومناسب لكل الأعمار بين مذيعين: ${podA.name} (شاب سعودي) و${podB.name} (بنت خليجية)، باللهجة السعودية البيضاء.';
      final prompt = 'اكتب ${i == 0 ? 'الحلقة الأولى' : 'الحلقة الثانية'} لهذا اليوم بعنوان "${t.title}".\n'
          '${podA.name} رأيه: ${t.a}. ${podB.name} رأيها: ${t.b}.\n'
          'من 10 إلى 12 مقطع بالتناوب، كل مقطع جملة أو جملتين (حد أقصى 30 كلمة). '
          '${i == 0 ? 'يبدأ ${podA.name} بالترحيب بالمستمعين في بودكاست موجان وتعريف الموضوع.' : 'يبدأ ${podA.name} بـ "رجعنا لكم" ويعرف الموضوع الثاني.'} '
          'يتناقشون بأمثلة من الحياة اليومية ويحترمون رأي بعض، وينتهي بخلاصة ودعوة المستمعين للكتابة في التعليقات. '
          'بدون إيموجي وبدون أسماء في بداية النص.\n'
          'أرجع JSON فقط بهذا الشكل: {"lines":[{"who":0,"text":"..."},{"who":1,"text":"..."}]} حيث who=0 هو ${podA.name} وwho=1 هي ${podB.name}.';
      final raw = await AiBrain.instance.json(system, prompt);
      final ep = parseEpisode(t.title, raw);
      if (ep == null) return null;
      out.add(ep);
    }
    return out;
  }

  static PodEpisode? parseEpisode(String topic, String? raw) {
    if (raw == null) return null;
    try {
      final s = raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1);
      final j = jsonDecode(s);
      final lines = j is Map ? j['lines'] : null;
      if (lines is! List) return null;
      return PodEpisode.fromJson({
        'topic': topic,
        'lines': [
          for (final l in lines)
            if (l is Map)
              {
                'who': l['who'] is num ? l['who'] : ('${l['who']}'.contains(podB.name) || '${l['who']}' == '1' ? 1 : 0),
                'text': '${l['text'] ?? ''}'.replaceAll('*', '').replaceAll('"', ''),
              },
        ],
      });
    } catch (_) {
      return null;
    }
  }
}
