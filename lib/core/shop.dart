import 'package:flutter/material.dart';

import '../games/ludo/ludo_engine.dart';

enum ShopKind { dice, board, item, bundle, frame, entrance, bubble }

/// سكن نرد: لون الوجه ولون النقاط.
class DiceSkin {
  const DiceSkin(this.faces, this.pip, {this.glow});
  final List<Color> faces;
  final Color pip;
  final Color? glow;
}

/// ثيم لوح لودو: لون الخانات والخطوط والإطار.
class BoardTheme {
  const BoardTheme({required this.cell, required this.line, required this.frame, required this.yardTint});
  final Color cell;
  final Color line;
  final List<Color> frame;
  final double yardTint;
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.price,
    this.emoji,
    this.amount = 1,
    this.description = '',
  });
  final String id;
  final ShopKind kind;
  final String title;
  final int price;
  final String? emoji;
  final int amount;
  final String description;
}

const diceSkins = <String, DiceSkin>{
  'classic': DiceSkin([Colors.white, Color(0xFFE4E1F0)], Color(0xFF1A1033)),
  'gold': DiceSkin([Color(0xFFFFE27A), Color(0xFFE09B12)], Color(0xFF6B3A00), glow: Color(0xFFFFC23D)),
  'ruby': DiceSkin([Color(0xFFFF6B81), Color(0xFFB0203A)], Colors.white, glow: Color(0xFFFF4D6D)),
  'emerald': DiceSkin([Color(0xFF6BF0B4), Color(0xFF14955E)], Colors.white, glow: Color(0xFF2EE59D)),
  'ocean': DiceSkin([Color(0xFF7FD3FF), Color(0xFF1B6FD1)], Colors.white, glow: Color(0xFF3DB8FF)),
  'galaxy': DiceSkin([Color(0xFF8E6CFF), Color(0xFF2B1466)], Color(0xFFFFE27A), glow: Color(0xFFB86CFF)),
};

const boardThemes = <String, BoardTheme>{
  'classic': BoardTheme(cell: Colors.white, line: Color(0xFFCFD3DC), frame: [Color(0xFFB9824A), Color(0xFF7A4B22)], yardTint: 0),
  'night': BoardTheme(cell: Color(0xFF2B2353), line: Color(0xFF453B7A), frame: [Color(0xFF6C4DFF), Color(0xFF2D1B69)], yardTint: .2),
  'desert': BoardTheme(cell: Color(0xFFFFF2D6), line: Color(0xFFE2C79A), frame: [Color(0xFFE0A35A), Color(0xFF9C5F24)], yardTint: .1),
};

const itemInfo = <LudoItem, (String, String, IconData, Color)>{
  LudoItem.doubleDistance: ('مسافة مضاعفة', 'تحرك ضعف رقم النرد', Icons.keyboard_double_arrow_left_rounded, Color(0xFF3DB8FF)),
  LudoItem.diceControl: ('تحكم بالنرد', 'اختر الرقم الذي تريده', Icons.casino_rounded, Color(0xFFFFC23D)),
  LudoItem.shield: ('درع حماية', 'قطعك لا تؤكل حتى يرجع دورك', Icons.shield_rounded, Color(0xFF2EE59D)),
};

const shopCatalog = <ShopItem>[
  ShopItem(id: 'dice.gold', kind: ShopKind.dice, title: 'نرد ذهبي', price: 1500),
  ShopItem(id: 'dice.ruby', kind: ShopKind.dice, title: 'نرد ياقوتي', price: 1500),
  ShopItem(id: 'dice.emerald', kind: ShopKind.dice, title: 'نرد زمردي', price: 1500),
  ShopItem(id: 'dice.ocean', kind: ShopKind.dice, title: 'نرد المحيط', price: 1500),
  ShopItem(id: 'dice.galaxy', kind: ShopKind.dice, title: 'نرد المجرة', price: 3000),
  ShopItem(id: 'board.night', kind: ShopKind.board, title: 'لوح الليل', price: 2500),
  ShopItem(id: 'board.desert', kind: ShopKind.board, title: 'لوح الصحراء', price: 2500),
  ShopItem(id: 'item.doubleDistance', kind: ShopKind.item, title: 'مسافة مضاعفة', price: 300, description: 'تحرك ضعف رقم النرد'),
  ShopItem(id: 'item.diceControl', kind: ShopKind.item, title: 'تحكم بالنرد', price: 500, description: 'اختر رقم النرد'),
  ShopItem(id: 'item.shield', kind: ShopKind.item, title: 'درع حماية', price: 400, description: 'حماية لدور كامل'),
  ShopItem(id: 'bundle.power', kind: ShopKind.bundle, title: 'حزمة الباور', price: 3000, amount: 3, emoji: '⚡', description: '3 من كل أداة'),
];

ShopItem shopItem(String id) => [...shopCatalog, ...styleCatalog].firstWhere((i) => i.id == id);

/// إطارات الصورة ودخوليات الغرف الصوتية وفقاعات الدردشة.
const styleCatalog = <ShopItem>[
  ShopItem(id: 'frame.hearts', kind: ShopKind.frame, title: 'إطار القلوب', price: 1500),
  ShopItem(id: 'frame.jungle', kind: ShopKind.frame, title: 'إطار الغابة', price: 1500),
  ShopItem(id: 'frame.ice', kind: ShopKind.frame, title: 'إطار الجليد', price: 2000),
  ShopItem(id: 'frame.rainbow', kind: ShopKind.frame, title: 'إطار قوس قزح', price: 2000),
  ShopItem(id: 'frame.fire', kind: ShopKind.frame, title: 'إطار النار', price: 2500),
  ShopItem(id: 'frame.demon', kind: ShopKind.frame, title: 'إطار القرون', price: 3000),
  ShopItem(id: 'frame.ramadan', kind: ShopKind.frame, title: 'إطار رمضان', price: 3500),
  ShopItem(id: 'frame.angel', kind: ShopKind.frame, title: 'إطار الأجنحة', price: 4000),
  ShopItem(id: 'frame.royal', kind: ShopKind.frame, title: 'إطار ملكي', price: 5000),
  ShopItem(id: 'frame.sakura', kind: ShopKind.frame, title: 'إطار الساكورا', price: 2500),
  ShopItem(id: 'frame.candy', kind: ShopKind.frame, title: 'إطار الحلويات', price: 2500),
  ShopItem(id: 'frame.ocean', kind: ShopKind.frame, title: 'إطار الموج', price: 3000),
  ShopItem(id: 'frame.desert', kind: ShopKind.frame, title: 'إطار الصحراء', price: 3000),
  ShopItem(id: 'frame.neon', kind: ShopKind.frame, title: 'إطار النيون', price: 3500),
  ShopItem(id: 'frame.emerald', kind: ShopKind.frame, title: 'إطار الزمرد', price: 4000),
  ShopItem(id: 'frame.storm', kind: ShopKind.frame, title: 'إطار البرق', price: 4500),
  ShopItem(id: 'frame.galaxy', kind: ShopKind.frame, title: 'إطار المجرة', price: 5500),
  ShopItem(id: 'frame.phoenix', kind: ShopKind.frame, title: 'إطار العنقاء', price: 6500),
  ShopItem(id: 'entrance.scooter', kind: ShopKind.entrance, title: 'سكوتر القلوب', price: 1500),
  ShopItem(id: 'entrance.car', kind: ShopKind.entrance, title: 'سيارة ذهبية', price: 3000),
  ShopItem(id: 'entrance.carpet', kind: ShopKind.entrance, title: 'البساط الطائر', price: 4000),
  ShopItem(id: 'entrance.horse', kind: ShopKind.entrance, title: 'الخيل العربي', price: 5000),
  ShopItem(id: 'entrance.yacht', kind: ShopKind.entrance, title: 'اليخت', price: 6000),
  ShopItem(id: 'entrance.rocket', kind: ShopKind.entrance, title: 'الصاروخ', price: 7000),
  ShopItem(id: 'entrance.dragon', kind: ShopKind.entrance, title: 'التنين', price: 8000),
  ShopItem(id: 'entrance.lion', kind: ShopKind.entrance, title: 'الأسد الملكي', price: 9000),
  ShopItem(id: 'entrance.jet', kind: ShopKind.entrance, title: 'الطائرة الخاصة', price: 12000),
  ShopItem(id: 'entrance.lamp', kind: ShopKind.entrance, title: 'المصباح السحري', price: 4500),
  ShopItem(id: 'entrance.unicorn', kind: ShopKind.entrance, title: 'وحيد القرن', price: 6500),
  ShopItem(id: 'entrance.falcon', kind: ShopKind.entrance, title: 'الصقر الذهبي', price: 8500),
  ShopItem(id: 'entrance.supercar', kind: ShopKind.entrance, title: 'السيارة الرياضية', price: 10000),
  ShopItem(id: 'entrance.ufo', kind: ShopKind.entrance, title: 'الصحن الطائر', price: 11000),
  ShopItem(id: 'entrance.carriage', kind: ShopKind.entrance, title: 'العربة الملكية', price: 15000),
  ShopItem(id: 'bubble.pink', kind: ShopKind.bubble, title: 'فقاعة وردية', price: 800),
  ShopItem(id: 'bubble.ocean', kind: ShopKind.bubble, title: 'فقاعة المحيط', price: 800),
  ShopItem(id: 'bubble.gold', kind: ShopKind.bubble, title: 'فقاعة ذهبية', price: 1500),
  ShopItem(id: 'bubble.neon', kind: ShopKind.bubble, title: 'فقاعة نيون', price: 1500),
  ShopItem(id: 'bubble.mint', kind: ShopKind.bubble, title: 'فقاعة النعناع', price: 1000),
  ShopItem(id: 'bubble.sunset', kind: ShopKind.bubble, title: 'فقاعة الغروب', price: 1200),
  ShopItem(id: 'bubble.ruby', kind: ShopKind.bubble, title: 'فقاعة الياقوت', price: 2000),
  ShopItem(id: 'bubble.emerald', kind: ShopKind.bubble, title: 'فقاعة الزمرد', price: 2000),
  ShopItem(id: 'bubble.galaxy', kind: ShopKind.bubble, title: 'فقاعة المجرة', price: 2500),
  ShopItem(id: 'bubble.royal', kind: ShopKind.bubble, title: 'فقاعة ملكية', price: 3000),
];

/// ألوان فقاعات الدردشة.
const bubbleStyles = <String, List<Color>>{
  'pink': [Color(0xFFFF7AB6), Color(0xFFFF4D9D)],
  'ocean': [Color(0xFF3DB8FF), Color(0xFF1B6FD1)],
  'gold': [Color(0xFFFFD66B), Color(0xFFE09B12)],
  'neon': [Color(0xFF7CF5FF), Color(0xFFB86CFF)],
  'mint': [Color(0xFF8DF5C8), Color(0xFF1FB58A)],
  'sunset': [Color(0xFFFFB25B), Color(0xFFFF5E62), Color(0xFFB83BD6)],
  'ruby': [Color(0xFFFF6B8B), Color(0xFFB0103A)],
  'emerald': [Color(0xFF3DDC84), Color(0xFF0B7A4B)],
  'galaxy': [Color(0xFF5B3BD6), Color(0xFFB04CE0), Color(0xFF1B1F6B)],
  'royal': [Color(0xFFFFE27A), Color(0xFFB8860B), Color(0xFF6A1B9A)],
};

String frameArt(String name) => 'fr_$name';
String entranceArt(String name) => 'ent_$name';
String entranceTitle(String name) => shopItem('entrance.$name').title;

/// هدايا البونص اليومي لسبعة أيام متتالية.
class DailyGift {
  const DailyGift({this.coins = 0, this.items = const {}, this.skin, required this.label, required this.emoji});
  final int coins;
  final Map<LudoItem, int> items;
  final String? skin;
  final String label;
  final String emoji;
}

const dailyGifts = <DailyGift>[
  DailyGift(coins: 300, label: '300', emoji: '🪙'),
  DailyGift(coins: 500, label: '500', emoji: '💰'),
  DailyGift(items: {LudoItem.shield: 2}, label: 'درع ×2', emoji: '🛡️'),
  DailyGift(coins: 600, label: '600', emoji: '🎁'),
  DailyGift(skin: 'dice.gold', coins: 0, label: 'نرد ذهبي', emoji: '🎲'),
  DailyGift(coins: 1000, label: '1000', emoji: '👜'),
  DailyGift(coins: 2000, items: {LudoItem.doubleDistance: 1, LudoItem.diceControl: 1, LudoItem.shield: 1}, label: '2000 + أدوات', emoji: '👑'),
];

/// خيارات الرهان في لودو: الدخول، والجائزة = الدخول × عدد اللاعبين ناقص 5٪.
const ludoEntries = [0, 200, 500, 1000, 2000, 5000];

int ludoPrize(int entry, int players, {bool teams = false}) {
  final pot = entry * players * 95 ~/ 100;
  return teams ? pot ~/ 2 : pot;
}
