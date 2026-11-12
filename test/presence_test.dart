import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/screens/admin/admin_screen.dart';

void main() {
  test('presence: in app, in background, out of app', () {
    final now = DateTime(2026, 11, 12, 18);
    Map<String, dynamic> u(String state, Duration ago) => {'state': state, 'seen': Timestamp.fromDate(now.subtract(ago))};
    expect(presenceOf(u('on', const Duration(seconds: 40)), now: now), PresenceState.online);
    expect(presenceOf(u('on', const Duration(minutes: 5)), now: now), PresenceState.offline, reason: 'heartbeat stopped');
    expect(presenceOf(u('away', const Duration(minutes: 5)), now: now), PresenceState.away);
    expect(presenceOf(u('away', const Duration(hours: 2)), now: now), PresenceState.offline);
    expect(presenceOf(u('off', const Duration(seconds: 5)), now: now), PresenceState.offline);
    expect(presenceOf(const {}, now: now), PresenceState.offline);
  });
}
