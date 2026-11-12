import 'dart:math';

/// قطعة: خلايا (صف، عمود) من الزاوية العلوية اليسرى، ولون.
class BlockPiece {
  const BlockPiece(this.cells, this.color);
  final List<(int, int)> cells;
  final int color;

  int get rows => cells.map((c) => c.$1).reduce(max) + 1;
  int get cols => cells.map((c) => c.$2).reduce(max) + 1;
}

/// أشكال القطع (بدون ألوان).
const blockShapes = <List<(int, int)>>[
  [(0, 0)],
  [(0, 0), (0, 1)],
  [(0, 0), (1, 0)],
  [(0, 0), (0, 1), (0, 2)],
  [(0, 0), (1, 0), (2, 0)],
  [(0, 0), (0, 1), (0, 2), (0, 3)],
  [(0, 0), (1, 0), (2, 0), (3, 0)],
  [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)],
  [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
  [(0, 0), (0, 1), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)],
  // زوايا صغيرة
  [(0, 0), (1, 0), (1, 1)],
  [(0, 1), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (1, 0)],
  [(0, 0), (0, 1), (1, 1)],
  // زوايا كبيرة
  [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)],
  [(0, 0), (0, 1), (0, 2), (1, 0), (2, 0)],
  [(0, 0), (0, 1), (0, 2), (1, 2), (2, 2)],
  [(0, 2), (1, 2), (2, 0), (2, 1), (2, 2)],
  // L
  [(0, 0), (1, 0), (2, 0), (2, 1)],
  [(0, 0), (0, 1), (0, 2), (1, 0)],
  [(0, 0), (0, 1), (1, 1), (2, 1)],
  [(0, 2), (1, 0), (1, 1), (1, 2)],
  // T
  [(0, 1), (1, 0), (1, 1), (1, 2)],
  [(0, 0), (0, 1), (0, 2), (1, 1)],
  [(0, 0), (1, 0), (1, 1), (2, 0)],
  [(0, 1), (1, 0), (1, 1), (2, 1)],
  // S و Z
  [(0, 1), (0, 2), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (1, 1), (1, 2)],
  [(0, 0), (1, 0), (1, 1), (2, 1)],
  [(0, 1), (1, 0), (1, 1), (2, 0)],
];

const blocksColors = 7;

class BlocksPlacement {
  const BlocksPlacement(this.placed, this.rows, this.cols, this.points);
  final int placed;
  final List<int> rows;
  final List<int> cols;
  final int points;
  int get lines => rows.length + cols.length;
}

/// لعبة المكعبات: لوحة 8×8، ثلاث قطع، امسح الصفوف والأعمدة الكاملة.
class BlocksGame {
  BlocksGame({Random? random, this.size = 8}) : _rng = random ?? Random() {
    board = List.generate(size, (_) => List.filled(size, -1));
    _refill();
  }

  final Random _rng;
  final int size;
  late List<List<int>> board;

  /// القطع الثلاث (null = مستخدمة).
  List<BlockPiece?> tray = [];
  int score = 0;

  /// عدد المرات المتتالية اللي مسحت فيها خطوط.
  int streak = 0;

  BlockPiece randomPiece() => BlockPiece(blockShapes[_rng.nextInt(blockShapes.length)], _rng.nextInt(blocksColors));

  void _refill() {
    tray = [for (var i = 0; i < 3; i++) randomPiece()];
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

  bool get over => tray.whereType<BlockPiece>().every((p) => !fitsAnywhere(p));

  /// الصفوف والأعمدة اللي تكتمل لو حطيت القطعة هنا (للمعاينة).
  (List<int>, List<int>) linesIf(BlockPiece p, int row, int col) {
    final filled = {for (final (r, c) in p.cells) (row + r, col + c)};
    bool full(int r, int c) => board[r][c] >= 0 || filled.contains((r, c));
    return (
      [for (var r = 0; r < size; r++) if (List.generate(size, (c) => full(r, c)).every((x) => x)) r],
      [for (var c = 0; c < size; c++) if (List.generate(size, (r) => full(r, c)).every((x) => x)) c],
    );
  }

  /// يحط القطعة رقم [index] ويرجع النتيجة، أو null لو ما تنفع.
  BlocksPlacement? place(int index, int row, int col) {
    final p = tray[index];
    if (p == null || !canPlace(p, row, col)) return null;
    for (final (r, c) in p.cells) {
      board[row + r][col + c] = p.color;
    }
    final (rows, cols) = linesIf(const BlockPiece([(0, 0)], 0), -99, -99);
    for (final r in rows) {
      board[r].fillRange(0, size, -1);
    }
    for (final c in cols) {
      for (var r = 0; r < size; r++) {
        board[r][c] = -1;
      }
    }
    final lines = rows.length + cols.length;
    streak = lines > 0 ? streak + 1 : 0;
    // نقطة لكل مربع، و10 لكل خط مضروبة في عدد الخطوط، ومكافأة السلسلة.
    final pts = p.cells.length + (lines == 0 ? 0 : 10 * lines * lines + 10 * (streak - 1));
    score += pts;
    tray[index] = null;
    if (tray.every((t) => t == null)) _refill();
    return BlocksPlacement(p.cells.length, rows, cols, pts);
  }
}
