import 'package:flutter/material.dart';

import '../core/account/account.dart';
import '../core/admin/admin.dart';
import '../core/account/auth_backend.dart';
import '../core/theme.dart';
import 'login_screen.dart';
import 'admin/admin_screen.dart';
import 'support_screen.dart';

const appVersion = '0.7.0';

/// الإعدادات: الاهتزاز، اللغة، الخصوصية، عن التطبيق، تسجيل الخروج.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => ListenableBuilder(
      listenable: Account.instance,
      builder: (ctx, _) {
        final acc = Account.instance;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'الإعدادات',
                  style: AppTheme.display.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  key: const ValueKey('haptics-switch'),
                  value: acc.haptics,
                  activeThumbColor: AppColors.gold,
                  onChanged: acc.setHaptics,
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text(
                    'الاهتزاز',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.language_rounded),
                  title: Text(
                    'اللغة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: Text(
                    'العربية',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: const Text(
                    'الخصوصية',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => _info(
                    ctx,
                    'الخصوصية',
                    'نحفظ اسمك وصورتك الرمزية ونتائجك لعرضها في حسابك ولوحة المتصدرين. '
                        'عند الدخول بجوجل أو برقم الهاتف نستخدمهما فقط للتعرف عليك. '
                        'يمكنك حذف بياناتك من الجهاز بتسجيل الخروج.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title: const Text(
                    'عن MOJAN',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: const Text(
                    'الإصدار $appVersion',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  onTap: () => _info(
                    ctx,
                    'عن MOJAN',
                    'منصة ألعاب جماعية: لودو، سيكو، أسئلة وأجوبة، وصراحة أو جرأة. والمزيد قريباً.'
                        '${authBackend.isDemo ? '\n\nتسجيل الدخول يعمل هنا في وضع التجربة، والحسابات الحقيقية تعمل من موقع MOJAN الرسمي.' : ''}',
                  ),
                ),
                if (!AdminService.instance.isAdmin)
                  ListTile(
                    key: const ValueKey('open-support'),
                    leading: const Icon(Icons.support_agent_rounded, color: AppColors.gold),
                    title: const Text('تواصل مع الإدارة', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('شحن العملات وأي مشكلة'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => openSupport(ctx),
                  ),
                if (AdminService.instance.isAdmin) ListTile(
                  key: const ValueKey('open-admin'),
                  leading: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.gold,
                  ),
                  title: const Text(
                    'لوحة تحكم الإدارة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => openAdmin(ctx),
                ),
                if (acc.signedIn) ...[
                  const Divider(color: Colors.white12),
                  ListTile(
                    key: const ValueKey('sign-out'),
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFF7A7A),
                    ),
                    title: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF7A7A),
                      ),
                    ),
                    onTap: () => _signOut(ctx),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _info(BuildContext context, String title, String body) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(body, style: const TextStyle(height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

Future<void> _signOut(BuildContext context) async {
  final guest =
      Account.instance.profile?.method == AuthMethod.guest ||
      authBackend.isDemo;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'تسجيل الخروج؟',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Text(
        guest
            ? 'حساب الضيف لا يمكن استرجاعه بعد الخروج، وسيضيع تقدمك وعملاتك. اربطه بجوجل أولاً لتحفظه.'
            : 'يمكنك الدخول مرة أخرى في أي وقت.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const ValueKey('confirm-sign-out'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A5F),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'خروج',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await Account.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
