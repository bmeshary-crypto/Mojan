import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/admin/admin.dart';
import 'package:mojan/core/admin/staff.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/screens/admin/admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final admin = AdminService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'مشرف');
    admin.reset();
    admin.adminOverride = null;
    Staff.instance.current.value = null;
  });

  tearDown(() => Staff.instance.current.value = null);

  test('roles carry their default permissions', () {
    expect(staffRoles['manager']!.$2, containsAll(staffPerms.keys));
    expect(staffRoles['supervisor']!.$2, isNot(contains('coins')));
    final s = StaffInfo.parse({'role': 'supervisor', 'perms': ['ban', 'rooms']})!;
    expect(s.perms, {'ban', 'rooms'});
    expect(StaffInfo.parse(s.toJson())!.perms, s.perms);
    expect(roleTitle('manager'), 'مدير');
  });

  test('can() follows the staff permissions, owner can everything', () {
    expect(admin.can('ban'), isFalse);
    Staff.instance.current.value = const StaffInfo(role: 'supervisor', perms: {'ban', 'reports'});
    expect(admin.can('ban'), isTrue);
    expect(admin.can('coins'), isFalse);
    expect(admin.isOwner, isFalse);
    admin.adminOverride = true;
    expect(admin.can('coins'), isTrue);
    expect(admin.isOwner, isTrue);
  });

  testWidgets('a supervisor sees only the allowed tabs and buttons', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Staff.instance.current.value = const StaffInfo(role: 'supervisor', perms: {'users', 'ban', 'reports'});
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const AdminScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('admin-tab-users')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-tab-reports')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-tab-rooms')), findsNothing);
    expect(find.byKey(const ValueKey('admin-tab-support')), findsNothing);
    expect(find.byKey(const ValueKey('admin-tab-team')), findsNothing);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: AdminUserPage(user: localUserDoc()!)));
    await tester.pump();
    expect(find.byKey(const ValueKey('user-ban')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-add-coins')), findsNothing);
    expect(find.byKey(const ValueKey('user-edit-profile')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('the owner sees the team tab', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    admin.adminOverride = true;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const AdminScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('admin-tab-team')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('admin-tab-team')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-tab-team')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-add')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
