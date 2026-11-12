import 'dart:math';

/// قطعة: خلايا (صف، عمود) من الزاوية العلوية اليسرى، ولون.
class BlockPiece {
  const BlockPiece(this.cells, this.color);
  final List<(int, int)> cells;
  final int color;

  int get rows => cells.map((c) => c.$1).reduce(max) + 1;
  int get cols => cells.map((c) => c.$2).reduce(max) + 1;

  /// تدوير 90° مع عقارب الساعة.
  BlockPiece rotated() {
    final r = rows;
    return BlockPiece([for (final (y, x) in cells) (x, r - 1 - y)], color);
  }
}

/// أشكال صغيرة (الوضع السهل يعتمد عليها).
const smallShapes = <List<(int, int)>>[
  [(0, 0)],
  [(0, 0), (0, 1)],
  [(0, 0), (1, 0)],
  [(0, 0), (0, 1), (0, 2)],
  [(0, 0), (1, 0), (2, 0)],
  [(0, 0), (0, 1), (1, 0), (1, 1)],
  [(0, 0), (1, 0), (1, 1)],
  [(0, 1), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (1, 0)],
  [(0, 0), (0, 1), (1, 1)],
  [(0, 1), (1, 0), (1, 1), (1, 2)],
  [(0, 0), (0, 1), (0, 2), (1, 1)],
];

/// أشكال كبيرة وصعبة.
const bigShapes = <List<(int, int)>>[
  [(0, 0), (0, 1), (0, 2), (0, 3)],
  [(0, 0), (1, 0), (2, 0), (3, 0)],
  [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)],
  [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
  [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)],
  [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
  [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)],
  [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)],
  [(0, 0), (0, 1), (0, 2), (1, 0), (2, 0)],
  [(0, 0), (0, 1), (0, 2), (1, 2), (2, 2)],
  [(0, 2), (1, 2), (2, 0), (2, 1), (2, 2)],
  [(0, 0), (1, 0), (2, 0), (2, 1)],
  [(0, 0), (0, 1), (0, 2), (1, 0)],
  [(0, 0), (0, 1), (1, 1), (2, 1)],
  [(0, 2), (1, 0), (1, 1), (1, 2)],
  [(0, 0), (1, 0), (1, 1), (2, 0)],
  [(0, 1), (1, 0), (1, 1), (2, 1)],
  [(0, 1), (0, 2), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (1, 1), (1, 2)],
  [(0, 0), (1, 0), (1, 1), (2, 1)],
  [(0, 1), (1, 0), (1, 1), (2, 0)],
  // صليب وقطري (صعب)
  [(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)],
  [(0, 0), (1, 1)],
  [(0, 1), (1, 0)],
  [(0, 0), (1, 1), (2, 2)],
];

/// كل الأشكال (للتوافق مع الكود القديم).
const blockShapes = [...smallShapes, ...bigShapes];

const blocksColors = 7;

enum BlocksMode {
  easy('سهل', '🌱', 'قطع صغيرة، دائماً تلقى مكان، وتقدر تتراجع 3 مرات', 8),
  classic('كلاسيك', '🟧', 'اللعبة الأصلية على لوحة 8×8', 8),
  hard('صعب', '🔥', 'قطع كبيرة وعشوائية بالكامل، بدون مساعدة', 8),
  pro('احترافي', '💎', 'لوحة 9×9 تنمسح فيها المربعات 3×3 أيضاً، مع قنبلة وتدوير وتبديل', 9);

  const BlocksMode(this.title, this.icon, this.desc, this.size);
  final String title;
  final String icon;
  final String desc;
  final int size;

  String get bestKey => 'blocks_best_$name';
}

enum BlockPower {
  bomb('💣', 'قنبلة', 'اضغط على أي خانة وتنفجر 3×3 حولها'),
  rotate('🔄', 'تدوير', 'اضغط على قطعة تحت وتدور'),
  shuffle('🔀', 'تبديل', 'ثلاث قطع جديدة');

  const BlockPower(this.icon, this.title, this.desc);
  final String icon;
  final String title;
  final String desc;
}

class BlocksPlacement {
  const BlocksPlacement(this.placed, this.rows, this.cols, this.boxes, this.points, {this.allClear = false, this.combo = 0, this.cleared = const {}});
  final int placed;
  final List<int> rows;
  final List<int> cols;

  /// مربعات 3×3 (الوضع الاحترافي): رقم المربع 0..8.
  final List<int> boxes;
  final int points;
  final bool allClear;

  /// عداد الكومبو بعد هذه الحركة (0 = ما فيه).
  final int combo;
  final Set<(int, int)> cleared;
  int get lines => rows.length + cols.length + boxes.length;
}

/// لعبة المكعبات: ضع القطع وامسح الصفوف والأعمدة الكاملة.
///
/// الكومبو مثل أشهر نسخ اللعبة: يبقى شغال لو مسحت خط خلال 3 حركات من آخر مسح.
class BlocksGame {
  BlocksGame({Random? random, this.mode = BlocksMode.classic}) : _rng = random ?? Random(), size = mode.size {
    board = List.generate(size, (_) => List.filled(size, -1));
    if (mode == BlocksMode.easy) undos = 3;
    if (mode == BlocksMode.pro) powers = {for (final p in BlockPower.values) p: 1};
    _refill();
  }

  final Random _rng;
  final BlocksMode mode;
  final int size;
  late List<List<int>> board;

  /// القطع الثلاث (null = مستخدمة).
  List<BlockPiece?> tray = [];
  int score = 0;

  /// عدد مرات المسح ضمن الكومبو الحالي.
  int combo = 0;

  /// الحركات من آخر مسح (الكومبو ينقطع بعد 3).
  int _sinceClear = 99;
  int get streak => combo;

  int undos = 0;
  Map<BlockPower, int> powers = {};
  _Snapshot? _undo;
  int linesTotal = 0;

  List<List<(int, int)>> get _pool => switch (mode) {
    BlocksMode.easy => smallShapes,
    BlocksMode.hard => [...bigShapes, ...bigShapes, ...smallShapes],
    _ => blockShapes,
  };

  BlockPiece randomPiece() {
    final pool = _pool;
    return BlockPiece(pool[_rng.nextInt(pool.length)], _rng.nextInt(blocksColors));
  }

  void _refill() {
    // في الأوضاع غير الصعبة نضمن إن قطعة وحدة على الأقل لها مكان (والسهل: كلها).
    for (var attempt = 0; attempt < 40; attempt++) {
      tray = [for (var i = 0; i < 3; i++) randomPiece()];
      if (mode == BlocksMode.hard) return;
      final fits = tray.whereType<BlockPiece>().where(fitsAnywhere).length;
      if (mode == BlocksMode.easy ? fits == 3 : fits >= 1) return;
    }
    if (mode != BlocksMode.hard) {
      tray[0] = const BlockPiece([(0, 0)], 0);
    }
  }

  bool canPlace(BlockPiece p, int row, int col) {
    for (final (r, c) in p.cells) {
      final rr = row + r, cc = col + c;
      if (rr < 0 || cc < 0 || rr >= size || cc >= size) return false;
      if (board[rr][cc] >= 0) return false;
    }
    return true;
  }

  bool fitsAnywhere(BlockPiece p) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (canPlace(p, r, c)) return true;
      }
    }
    return false;
  }

  bool get _hasRescue =>
      (powers[BlockPower.bomb] ?? 0) > 0 || (powers[BlockPower.shuffle] ?? 0) > 0 || undos > 0 && _undo != null ||
      ((powers[BlockPower.rotate] ?? 0) > 0 && tray.whereType<BlockPiece>().any((p) => fitsAnywhere(p.rotated()) || fitsAnywhere(p.rotated().rotated().rotated())));

  /// خلصت اللعبة: ولا قطعة لها مكان وما فيه أداة تنقذ.
  bool get over => tray.whereType<BlockPiece>().every((p) => !fitsAnywhere(p)) && !_hasRescue;

  /// ما فيه حركة بالقطع الحالية (حتى لو فيه أدوات).
  bool get stuck => tray.whereType<BlockPiece>().every((p) => !fitsAnywhere(p));

  bool get hasBoxes => mode == BlocksMode.pro;

  /// الصفوف والأعمدة والمربعات اللي تكتمل لو حطيت القطعة هنا.
  (List<int>, List<int>, List<int>) linesIf(BlockPiece? p, int row, int col) {
    final filled = {if (p != null) for (final (r, c) in p.cells) (row + r, col + c)};
    bool full(int r, int c) => board[r][c] >= 0 || filled.contains((r, c));
    return (
      [for (var r = 0; r < size; r++) if (List.generate(size, (c) => full(r, c)).every((x) => x)) r],
      [for (var c = 0; c < size; c++) if (List.generate(size, (r) => full(r, c)).every((x) => x)) c],
      [
        if (hasBoxes)
          for (var b = 0; b < 9; b++)
            if ([for (var i = 0; i < 9; i++) full(b ~/ 3 * 3 + i ~/ 3, b % 3 * 3 + i % 3)].every((x) => x)) b,
      ],
    );
  }

  Set<(int, int)> cellsOf(List<int> rows, List<int> cols, List<int> boxes) => {
    for (final r in rows)
      for (var c = 0; c < size; c++) (r, c),
    for (final c in cols)
      for (var r = 0; r < size; r++) (r, c),
    for (final b in boxes)
      for (var i = 0; i < 9; i++) (b ~/ 3 * 3 + i ~/ 3, b % 3 * 3 + i % 3),
  };

  _Snapshot _snap() => _Snapshot([for (final r in board) List.of(r)], List.of(tray), score, combo, _sinceClear, linesTotal);

  bool get canUndo => undos > 0 && _undo != null;

  void undo() {
    final s = _undo;
    if (s == null || undos <= 0) return;
    board = s.board;
    tray = s.tray;
    score = s.score;
    combo = s.combo;
    _sinceClear = s.since;
    linesTotal = s.lines;
    undos--;
    _undo = null;
  }

  /// يحط القطعة رقم [index] ويرجع النتيجة، أو null لو ما تنفع.
  BlocksPlacement? place(int index, int row, int col) {
    final p = tray[index];
    if (p == null || !canPlace(p, row, col)) return null;
    if (mode == BlocksMode.easy) _undo = _snap();
    for (final (r, c) in p.cells) {
      board[row + r][col + c] = p.color;
    }
    final (rows, cols, boxes) = linesIf(null, 0, 0);
    final cleared = cellsOf(rows, cols, boxes);
    for (final (r, c) in cleared) {
      board[r][c] = -1;
    }
    final lines = rows.length + cols.length + boxes.length;
    _sinceClear++;
    if (lines > 0) {
      combo = _sinceClear <= 3 ? combo + 1 : 1;
      _sinceClear = 0;
      linesTotal += lines;
    } else if (_sinceClear > 3) {
      combo = 0;
    }
    final allClear = lines > 0 && board.every((r) => r.every((v) => v < 0));
    // نقطة لكل مربع، و10 لكل خط مضروبة في عدد الخطوط، ومكافأة الكومبو وتصفير اللوحة.
    var pts = p.cells.length;
    if (lines > 0) pts += 10 * lines * lines + 10 * lines * (combo - 1);
    if (allClear) pts += 300;
    score += pts;
    // الاحترافي: كل كومبو ×3 أو تصفير يعطيك أداة.
    if (mode == BlocksMode.pro && lines > 0 && (combo % 3 == 0 || allClear || lines >= 3)) {
      final pw = BlockPower.values[_rng.nextInt(BlockPower.values.length)];
      powers[pw] = (powers[pw] ?? 0) + 1;
    }
    tray[index] = null;
    if (tray.every((t) => t == null)) _refill();
    return BlocksPlacement(p.cells.length, rows, cols, boxes, pts, allClear: allClear, combo: lines > 0 ? combo : 0, cleared: cleared);
  }

  /// قنبلة: تمسح 3×3 حول الخانة.
  Set<(int, int)> bomb(int row, int col) {
    if ((powers[BlockPower.bomb] ?? 0) <= 0) return {};
    powers[BlockPower.bomb] = powers[BlockPower.bomb]! - 1;
    final hit = <(int, int)>{};
    for (var r = row - 1; r <= row + 1; r++) {
      for (var c = col - 1; c <= col + 1; c++) {
        if (r >= 0 && c >= 0 && r < size && c < size && board[r][c] >= 0) {
          board[r][c] = -1;
          hit.add((r, c));
        }
      }
    }
    return hit;
  }

  bool rotate(int index) {
    final p = tray[index];
    if (p == null || (powers[BlockPower.rotate] ?? 0) <= 0) return false;
    powers[BlockPower.rotate] = powers[BlockPower.rotate]! - 1;
    tray[index] = p.rotated();
    return true;
  }

  bool shuffle() {
    if ((powers[BlockPower.shuffle] ?? 0) <= 0) return false;
    powers[BlockPower.shuffle] = powers[BlockPower.shuffle]! - 1;
    _refill();
    return true;
  }
}

class _Snapshot {
  _Snapshot(this.board, this.tray, this.score, this.combo, this.since, this.lines);
  final List<List<int>> board;
  final List<BlockPiece?> tray;
  final int score, combo, since, lines;
}
