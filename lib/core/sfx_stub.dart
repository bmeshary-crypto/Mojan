class Sfx {
  Sfx._();
  static final instance = Sfx._();
  void tap() {}
  void tone(double from, double to, double dur, {String type = 'sine', double vol = .2, double delay = 0}) {}
  void tick() {}
  void win() {}
  void lose() {}
}
