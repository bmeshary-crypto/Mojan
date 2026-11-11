import 'package:flutter/material.dart';

import '../games/ludo/ludo_engine.dart';

enum ShopKind { dice, board, item, bundle }

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

ShopItem shopItem(String id) => shopCatalog.firstWhere((i) => i.id == id);

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
