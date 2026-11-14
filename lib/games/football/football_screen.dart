import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/landscape.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/game_ui.dart';
import 'football_view.dart';

const footballColors = [Color(0xFF7CF28A), Color(0xFF1E9E4A), Color(0xFF0B3D1F)];

/// أندية خيالية (نفس شعارات «دوري النجوم»). يجب أن تطابق CLUBS في football3d/src/teams.js
class FootballClub {
  const FootballClub(this.id, this.name, this.c1, this.c2);
  final String id;
  final String name;
  final Color c1;
  final Color c2;
}

const footballClubs = [
  FootballClub('eagle', 'النسور', Color(0xFF2F7BFF), Color(0xFF0B2A6B)),
  FootballClub('lion', 'الأسود', Color(0xFFFFC21A), Color(0xFFB3261E)),
  FootballClub('falcon', 'الصقور', Color(0xFFF4F4F4), Color(0xFF0D7A3F)),
  FootballClub('wolf', 'الذئاب', Color(0xFF8C9AB0), Color(0xFF1E2A44)),
  FootballClub('tiger', 'النمور', Color(0xFFFF8A1F), Color(0xFF2A1A0A)),
  FootballClub('shark', 'القروش', Color(0xFF1FC6C9), Color(0xFF0A4048)),
  FootballClub('bull', 'الثيران', Color(0xFFE02424), Color(0xFFFFC93C)),
  FootballClub('cobra', 'الأفاعي', Color(0xFF3DDC6A), Color(0xFF0E2E18)),
  FootballClub('bear', 'الدببة', Color(0xFFB0413E), Color(0xFF3A0E12)),
  FootballClub('fox', 'الثعالب', Color(0xFFFF6A2B), Color(0xFFF2F2F2)),
  FootballClub('horse', 'الخيول', Color(0xFFC98A4B), Color(0xFF4A2A12)),
  FootballClub('camel', 'الجمال', Color(0xFFE8D3A6), Color(0xFF7A4B1F)),
];

enum FootballDiff {
  easy('سهل'),
  normal('متوسط'),
  hard('صعب');

  const FootballDiff(this.label);
  final String label;
}

/// رهان المباراة: الفوز = ضعف الرهان، التعادل = استرجاعه.
const footballStakes = [0, 200, 500, 1000];

/// نتيجة مباراة تعود من شاشة اللعب.
class FootballResult {
  FootballResult({required this.home, required this.away, required this.quit, this.possession = 50, this.shots = 0});
  final int home;
  final int away;
  final bool quit;
  final int possession;
  final int shots;
  bool get won => !quit && home > away;
  bool get draw => !quit && home == away;
}

/// شاشة إعداد «كرة القدم 3D».
class FootballScreen extends StatefulWidget {
  const FootballScreen({super.key});

  @override
  State<FootballScreen> createState() => _FootballScreenState();
}

class _FootballScreenState extends State<FootballScreen> {
  int _home = 0;
  int _away = 1;
  FootballDiff _diff = FootballDiff.normal;
  int _mins = 4;
  int _stake = 0;

  @override
  Widget build(BuildContext context) {
    final st = Account.instance.profile?.statsFor('football');
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              const GameTopBar(title: 'كرة القدم 3D', subtitle: 'مباراة 11 ضد 11'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _banner(),
                          const SizedBox(height: 16),
                          if (st != null && st.played > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                _stat('🎮', '${st.played}', 'مباريات'),
                                _stat('🏆', '${st.wins}', 'فوز'),
                                _stat('⭐', '${st.points}', 'نقاط'),
                              ]),
                            ),
                          _label('فريقك'),
                          _clubs(_home, (i) => setState(() {
                                _home = i;
                                if (_away == i) _away = (i + 1) % footballClubs.length;
                              })),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: _label('الخصم')),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                final r = Random();
                                do {
                                  _away = r.nextInt(footballClubs.length);
                                } while (_away == _home);
                              }),
                              icon: const Icon(Icons.shuffle_rounded, size: 18),
                              label: const Text('عشوائي', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ]),
                          _clubs(_away, (i) => setState(() {
                                if (i != _home) _away = i;
                              }), disabled: _home),
                          const SizedBox(height: 16),
                          _label('الصعوبة'),
                          ChoiceRow<FootballDiff>(
                            options: [for (final d in FootballDiff.values) (d, d.label)],
                            value: _diff,
                            onChanged: (d) => setState(() => _diff = d),
                          ),
                          const SizedBox(height: 14),
                          _label('مدة المباراة'),
                          ChoiceRow<int>(
                            options: const [(2, '2 دقيقة'), (4, '4 دقائق'), (6, '6 دقائق')],
                            value: _mins,
                            onChanged: (m) => setState(() => _mins = m),
                          ),
                          const SizedBox(height: 14),
                          _label('الرهان'),
                          ChoiceRow<int>(
                            options: [for (final s in footballStakes) (s, s == 0 ? 'ودية' : '🪙 $s')],
                            value: _stake,
                            onChanged: (s) => setState(() => _stake = s),
                          ),
                          if (_stake > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('الفوز يعطيك 🪙 ${_stake * 2} · التعادل يرجع رهانك',
                                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                          const SizedBox(height: 16),
                          _howTo(),
                          const SizedBox(height: 20),
                          BigButton(label: '⚽  ابدأ المباراة', colors: footballColors, onTap: _start),
                          const SizedBox(height: 10),
                          Text('الأونلاين ضد لاعبين حقيقيين قريباً',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    Sfx.instance.tap();
    if (_stake > 0 && !Account.instance.spend(_stake)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('عملاتك لا تكفي لهذا الرهان', style: TextStyle(fontWeight: FontWeight.w700)),
        ));
      return;
    }
    enterLandscape();
    final home = footballClubs[_home], away = footballClubs[_away];
    final cfg = 'home=${home.id}&away=${away.id}&diff=${_diff.name}&mins=$_mins';
    final res = await Navigator.of(context).push<FootballResult>(MaterialPageRoute(
      builder: (_) => FootballMatchScreen(config: cfg),
    ));
    await exitLandscape();
    if (!mounted) return;
    final r = res ?? FootballResult(home: 0, away: 0, quit: true);
    _settle(r, home, away);
  }

  void _settle(FootballResult r, FootballClub home, FootballClub away) {
    final stake = _stake;
    var coins = 0;
    if (r.won) {
      coins = stake * 2;
    } else if (r.draw) {
      coins = stake;
    }
    Account.instance.earn(coins);
    final points = r.quit ? 0 : r.home * 100 + (r.won ? 300 : r.draw ? 100 : 0);
    final reward = Account.instance.recordGame('football', won: r.won, points: points);
    if (r.won) {
      Sfx.instance.bigWin();
    } else if (!r.draw) {
      Sfx.instance.lose();
    }
    setState(() {});
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameResultDialog(
        reward: reward,
        emoji: r.quit ? '🏳️' : r.won ? '🏆' : r.draw ? '🤝' : '😞',
        title: r.quit ? 'انسحبت من المباراة' : r.won ? 'فوز رائع!' : r.draw ? 'تعادل' : 'خسارة',
        rows: [
          _row('⚽', '${home.name} - ${away.name}', '${r.home} - ${r.away}'),
          if (!r.quit) _row('📊', 'الاستحواذ', '${r.possession}%'),
          if (!r.quit) _row('🎯', 'تسديداتك', '${r.shots}'),
          if (stake > 0) _row('🪙', 'الرهان', r.won ? '+$coins' : r.draw ? 'رجع $coins' : '-$stake'),
          _row('⭐', 'النقاط', '+$points'),
        ],
        onAgain: () {
          Navigator.pop(ctx);
          _start();
        },
        onHome: () {
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      );

  Widget _clubs(int value, ValueChanged<int> onTap, {int? disabled}) => SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: footballClubs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = footballClubs[i];
            final sel = i == value;
            final off = i == disabled;
            return GestureDetector(
              onTap: off ? null : () => onTap(i),
              child: Opacity(
                opacity: off ? .3 : 1,
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: 72,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [c.c1.withValues(alpha: sel ? .55 : .18), c.c2.withValues(alpha: sel ? .55 : .18)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.all(color: sel ? AppColors.gold : Colors.white24, width: sel ? 3 : 1),
                    boxShadow: [if (sel) BoxShadow(color: AppColors.gold.withValues(alpha: .5), blurRadius: 12)],
                  ),
                  child: Column(children: [
                    Expanded(
                      child: Image.asset('assets/images/fc_${c.id}.webp',
                          errorBuilder: (_, _, _) => const Text('⚽', style: TextStyle(fontSize: 30))),
                    ),
                    Text(c.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            );
          },
        ),
      );

  Widget _banner() => Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: footballColors, begin: Alignment.topRight, end: Alignment.bottomLeft),
          boxShadow: [BoxShadow(color: footballColors[1].withValues(alpha: .5), blurRadius: 24)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/football_cover.webp', fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xCC000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(children: [
                _crest(footballClubs[_home]),
                const Spacer(),
                const Text('VS', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.gold)),
                const Spacer(),
                _crest(footballClubs[_away]),
              ]),
            ),
          ]),
        ),
      );

  Widget _crest(FootballClub c) => Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Image.asset('assets/images/fc_${c.id}.webp', errorBuilder: (_, _, _) => const Text('⚽')),
        ),
        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 6)])),
      ]);

  Widget _stat(String e, String v, String l) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text('$e $v', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      );

  Widget _howTo() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(18)),
        child: const Text(
          '🕹️ العصا يسار الشاشة للحركة\n'
          '🟢 تمرير (اضغط مطولاً لكرة عالية) · 🔴 تسديد (اضغط مطولاً للقوة)\n'
          '🔵 سرعة للجري · بدون كرة: تبديل اللاعب وافتكاك (مع السرعة = انزلاق)\n'
          '⌨️ على الكمبيوتر: الأسهم، X تمرير، Space تسديد، Shift سرعة، V الكاميرا',
          style: TextStyle(height: 1.8, fontSize: 13),
        ),
      );

  Widget _row(String e, String l, String v) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Flexible(child: Text('$e  $l', style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
        ]),
      );
}

/// شاشة المباراة: تستضيف صفحة اللعبة ثلاثية الأبعاد.
class FootballMatchScreen extends StatefulWidget {
  const FootballMatchScreen({super.key, required this.config});
  final String config;

  @override
  State<FootballMatchScreen> createState() => _FootballMatchScreenState();
}

class _FootballMatchScreenState extends State<FootballMatchScreen> {
  FootballResult? _result;

  void _onMessage(Map<String, dynamic> m) {
    switch (m['event']) {
      case 'end':
        _result = FootballResult(
          home: (m['home'] as num?)?.toInt() ?? 0,
          away: (m['away'] as num?)?.toInt() ?? 0,
          quit: false,
          possession: (m['possession'] as num?)?.toInt() ?? 50,
          shots: ((m['shots'] as List?)?.first as num?)?.toInt() ?? 0,
        );
        setState(() {});
      case 'close':
        if (mounted) Navigator.of(context).pop(_result);
      case 'quit':
        if (mounted) {
          Navigator.of(context).pop(FootballResult(
            home: (m['home'] as num?)?.toInt() ?? 0,
            away: (m['away'] as num?)?.toInt() ?? 0,
            quit: true,
          ));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LeaveGuard(
      enabled: _result == null,
      message: 'المباراة ما خلصت، وإذا خرجت تنحسب خسارة.',
      child: Scaffold(
        backgroundColor: const Color(0xFF070B18),
        body: FootballView(config: widget.config, onMessage: _onMessage),
      ),
    );
  }
}
