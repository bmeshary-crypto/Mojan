import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/ai/ai_brain.dart';
import 'package:mojan/core/rounds/shared_rounds.dart';
import 'package:mojan/core/voice/podcast_content.dart';
import 'package:mojan/core/voice/system_rooms.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final svc = VoiceService.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    svc.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
  });
  tearDown(() {
    AiBrain.instance.override = null;
    SharedClock.fixedMs = null;
  });

  test('only the two system rooms exist, pinned on top, user rooms have no AI', () {
    svc.ensureRooms();
    expect(svc.rooms.map((r) => r.id), [SystemRooms.welcomeId, SystemRooms.podcastId]);
    final mine = svc.create(title: 'غرفتي', category: VoiceCategory.chat);
    mine.heat = 999999;
    expect(svc.live.take(2).every((r) => r.system != null), isTrue);
    expect(svc.aiOnMics(mine), isEmpty);
  });

  test('podcast mics are for the two AI hosts only', () {
    svc.ensureRooms();
    final pod = svc.byId(SystemRooms.podcastId)!;
    expect(svc.aiOnMics(pod).length, 2);
    for (final s in pod.seats) {
      expect(svc.takeSeat(pod, s.index), contains('للمذيعين فقط'));
    }
    svc.invite(pod);
    expect(pod.onMics.where((u) => !u.isAi), isEmpty);
  });

  test('podcast plays the same line for everyone at the same time', () async {
    svc.ensureRooms();
    final pod = svc.byId(SystemRooms.podcastId)!;
    final day = SystemRooms.dayOf(DateTime.utc(2026, 11, 12, 12).millisecondsSinceEpoch);
    SharedClock.fixedMs = SystemRooms.dayStart(day) + 1000;
    svc.join(pod);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(pod.caption, isNotNull);
    expect(pod.captionBy?.aiId, SystemRooms.podA.id, reason: 'host opens the episode');
    expect(pod.host.speaking, isTrue);
    final at = SystemRooms.instance.podcastAt(SharedClock.nowMs())!;
    expect(at.line.text, pod.caption);
    svc.leave(pod);
    expect(pod.caption, isNull);
  });

  test('podcast chat gets a written reply only', () async {
    AiBrain.instance.override = (s, p) async => 'ريم: أهلاً موكا، رأيك حلو 🌹';
    svc.ensureRooms();
    final pod = svc.byId(SystemRooms.podcastId)!;
    svc.sendMessage(pod, 'ريم أنا معك');
    await Future.delayed(const Duration(seconds: 1));
    final reply = pod.messages.lastWhere((m) => m.user?.isAi == true);
    expect(reply.text, 'أهلاً موكا، رأيك حلو 🌹');
    expect(reply.user!.aiId, SystemRooms.podB.id);
    expect(pod.seats[0].user!.speaking, isFalse, reason: 'comment replies are not spoken');
  });

  test('welcome room greets the new member by name, then the Egyptian line', () async {
    final asks = <String>[];
    AiBrain.instance.override = (s, p) async {
      asks.add(p);
      return asks.length == 1 ? 'هلا موكا! يا مرحبا يا موكا' : 'أهلاً يا موكا نورت';
    };
    svc.ensureRooms();
    final w = svc.byId(SystemRooms.welcomeId)!;
    svc.join(w);
    await Future.delayed(const Duration(seconds: 7));
    final ai = w.messages.where((m) => m.user?.isAi == true).toList();
    expect(ai.length, 2);
    expect(ai[0].user!.aiId, SystemRooms.welcomeHost.id);
    expect(asks[0], allOf(contains('موكا'), contains('شعر')));
    expect(ai[1].user!.aiId, SystemRooms.welcomeEgypt.id);
    expect(asks[1], contains('مصرية'));
    svc.leave(w);
  });

  test('backup Arabic podcast is at the same spot for everyone', () {
    final base = SystemRooms.dayStart(SystemRooms.dayOf(DateTime.utc(2026, 11, 12).millisecondsSinceEpoch));
    expect(SystemRooms.radioAt(base), (index: 0, offset: 0));
    expect(SystemRooms.radioAt(base + 1005 * 1000), (index: 1, offset: 5));
    expect(radioItems.every((r) => r.url.startsWith('https://news.un.org/')), isTrue);
  });

  test('generated episodes are parsed safely', () {
    final ep = SystemRooms.parseEpisode('موضوع', 'نص {"lines":[{"who":0,"text":"هلا"},{"who":"ريم","text":"*أهلين*"},{"who":0,"text":"a"},{"who":1,"text":"b"}]} زائد');
    expect(ep!.lines.length, 4);
    expect(ep.lines[1].who, 1);
    expect(ep.lines[1].text, 'أهلين');
    expect(SystemRooms.parseEpisode('x', 'not json'), isNull);
    expect(PodEpisode.fromJson(ep.toJson())!.lines.length, 4);
    expect(podTopics.length, greaterThanOrEqualTo(30));
  });
}
