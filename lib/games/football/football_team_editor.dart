import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/game_ui.dart';
import 'football_screen.dart';

const _palette = [
  Color(0xFFF4F4F4), Color(0xFF16181D), Color(0xFFE02424), Color(0xFF9B111E), Color(0xFFFF6A2B),
  Color(0xFFFFC21A), Color(0xFFE8D3A6), Color(0xFF3DDC6A), Color(0xFF0D7A3F), Color(0xFF1FC6C9),
  Color(0xFF6CCBFF), Color(0xFF2F7BFF), Color(0xFF0B2A6B), Color(0xFF7D3CFF), Color(0xFFFF6BD5),
  Color(0xFF8C9AB0), Color(0xFF6B3E1F), Color(0xFFB0413E),
];

const _patterns = ['سادة', 'مقلّم', 'حزام', 'نصفين'];
const _numbers = [1, 2, 4, 5, 3, 7, 8, 6, 11, 9, 10];
const _roles = ['حارس', 'مدافع', 'مدافع', 'مدافع', 'مدافع', 'وسط', 'وسط', 'وسط', 'وسط', 'مهاجم', 'مهاجم'];

/// فريق المستخدم: الاسم والألوان وأسماء اللاعبين يكتبها بنفسه (يُحفظ على الجهاز).
class MyFootballTeam {
  MyFootballTeam({required this.name, required this.c1, required this.c2, required this.shorts, required this.pattern, required this.names});

  factory MyFootballTeam.fresh() => MyFootballTeam(
        name: 'فريقي',
        c1: const Color(0xFF2F7BFF),
        c2: const Color(0xFFF4F4F4),
        shorts: const Color(0xFFF4F4F4),
        pattern: 0,
        names: List.filled(11, ''),
      );

  String name;
  Color c1;
  Color c2;
  Color shorts;
  int pattern;
  List<String> names;

  static const _key = 'football_my_team';

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  FootballClub get asClub => FootballClub('custom', name, c1, c2);

  /// إعدادات الرابط للعبة (football3d/src/main.js).
  String toConfig() => Uri(queryParameters: {
        'home': 'custom',
        'hname': name,
        'hc1': _hex(c1),
        'hc2': _hex(c2),
        'hsh': _hex(shorts),
        'hpat': '$pattern',
        'names': names.map((n) => n.replaceAll('|', ' ').trim()).join('|'),
      }).query;

  Map<String, dynamic> toJson() => {
        'name': name,
        'c1': c1.toARGB32(),
        'c2': c2.toARGB32(),
        'shorts': shorts.toARGB32(),
        'pattern': pattern,
        'names': names,
      };

  static Future<MyFootballTeam?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_key);
      if (s == null) return null;
      final j = jsonDecode(s) as Map<String, dynamic>;
      final names = [for (final n in (j['names'] as List? ?? const [])) '$n'];
      while (names.length < 11) {
        names.add('');
      }
      return MyFootballTeam(
        name: '${j['name'] ?? 'فريقي'}',
        c1: Color(j['c1'] as int),
        c2: Color(j['c2'] as int),
        shorts: Color(j['shorts'] as int),
        pattern: (j['pattern'] as int?) ?? 0,
        names: names.take(11).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(toJson()));
  }

  MyFootballTeam copy() => MyFootballTeam(name: name, c1: c1, c2: c2, shorts: shorts, pattern: pattern, names: [...names]);
}

/// شعار فريق المستخدم: درع بألوانه وأول حرف من اسمه (مثل الذي تعرضه اللعبة).
class MyTeamCrest extends StatelessWidget {
  const MyTeamCrest({super.key, required this.team});
  final MyFootballTeam team;

  @override
  Widget build(BuildContext context) {
    final ch = team.name.trim().isEmpty ? '?' : team.name.trim().characters.first;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipPath(
        clipper: _Shield(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [team.c1, team.c1, team.c2, team.c2], stops: const [0, .5, .5, 1]),
          ),
          child: Center(
            child: Text(ch,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
          ),
        ),
      ),
    );
  }
}

class _Shield extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .5, s.height * .05)
    ..lineTo(s.width * .9, s.height * .17)
    ..lineTo(s.width * .86, s.height * .61)
    ..quadraticBezierTo(s.width * .75, s.height * .84, s.width * .5, s.height * .95)
    ..quadraticBezierTo(s.width * .25, s.height * .84, s.width * .14, s.height * .61)
    ..lineTo(s.width * .1, s.height * .17)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// شاشة «محرر الفريق».
class FootballTeamEditor extends StatefulWidget {
  const FootballTeamEditor({super.key, required this.initial});
  final MyFootballTeam initial;

  @override
  State<FootballTeamEditor> createState() => _FootballTeamEditorState();
}

class _FootballTeamEditorState extends State<FootballTeamEditor> {
  late final MyFootballTeam t = widget.initial.copy();
  late final _name = TextEditingController(text: t.name);
  late final _players = [for (var i = 0; i < 11; i++) TextEditingController(text: t.names[i])];

  @override
  void dispose() {
    _name.dispose();
    for (final c in _players) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    t.name = _name.text.trim().isEmpty ? 'فريقي' : _name.text.trim();
    t.names = [for (final c in _players) c.text.trim()];
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(children: [
            const GameTopBar(title: 'محرر الفريق', subtitle: 'اسم فريقك وألوانه ولاعبيه'),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        SizedBox(width: 70, height: 70, child: MyTeamCrest(team: t)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _name,
                            maxLength: 20,
                            onChanged: (v) => setState(() => t.name = v),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            decoration: const InputDecoration(labelText: 'اسم الفريق', counterText: ''),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _label('لون القميص'),
                      _colors(t.c1, (c) => setState(() => t.c1 = c)),
                      const SizedBox(height: 12),
                      _label('اللون الثاني'),
                      _colors(t.c2, (c) => setState(() => t.c2 = c)),
                      const SizedBox(height: 12),
                      _label('لون الشورت'),
                      _colors(t.shorts, (c) => setState(() => t.shorts = c)),
                      const SizedBox(height: 12),
                      _label('شكل القميص'),
                      ChoiceRow<int>(
                        options: [for (var i = 0; i < _patterns.length; i++) (i, _patterns[i])],
                        value: t.pattern,
                        onChanged: (p) => setState(() => t.pattern = p),
                      ),
                      const SizedBox(height: 18),
                      _label('أسماء اللاعبين (اختياري)'),
                      for (var i = 0; i < 11; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: t.c1, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.c2, width: 2)),
                              child: Text('${_numbers[i]}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: t.c1.computeLuminance() > .6 ? Colors.black : Colors.white)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _players[i],
                                maxLength: 16,
                                decoration: InputDecoration(hintText: _roles[i], counterText: '', isDense: true),
                              ),
                            ),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      BigButton(label: '💾  حفظ الفريق', colors: footballColors, pulse: false, onTap: _save),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      );

  Widget _colors(Color value, ValueChanged<Color> onTap) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _palette)
            GestureDetector(
              onTap: () => onTap(c),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: c == value ? AppColors.gold : Colors.white24, width: c == value ? 4 : 1.5),
                ),
              ),
            ),
        ],
      );
}
