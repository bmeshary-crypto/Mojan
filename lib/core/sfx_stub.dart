class Sfx {
  Sfx._();
  static final instance = Sfx._();
  void tap() {}
  void tone(double from, double to, double dur, {String type = 'sine', double vol = .2, double delay = 0}) {}
  void tick() {}
  void win() {}
  void lose() {}
  void noise(double dur, {double vol = .25, double freq = 2500, double q = 1, double delay = 0, String filter = 'bandpass'}) {}
  void diceShake() {}
  void diceLand() {}
  void hop([int step = 0]) {}
  void capture() {}
  void release() {}
  void home() {}
  void pickup() {}
}
