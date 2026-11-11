import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/theme.dart';
import '../games/game_registry.dart';
import '../widgets/account_widgets.dart';
import '../widgets/bouncy_button.dart';
import 'login_screen.dart';
import 'settings_sheet.dart';

/// تبويب "حسابي": الصورة والاسم والمستوى والإحصائيات والإنجازات.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Account.instance,
      builder: (context, _) {
        final p = Account.instance.profile;
        if (p == null) return const SizedBox.shrink();
        final (level, into, need) = PlayerProfile.levelOf(p.xp);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Row(
              children: [
                Text('حسابي', style: AppTheme.display.copyWith(fontSize: 30)),
                const Spacer(),
                IconButton(
                  key: const ValueKey('open-settings'),
                  onPressed: () => showSettingsSheet(context),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        key: const ValueKey('edit-avatar'),
                        onTap: () => _pickAvatar(context, p.avatar),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PlayerAvatar(index: p.avatar, size: 84),
                            Positioned(
                              bottom: -2,
                              left: -2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: AppColors.bgTop,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('edit-name'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _rename(context, p.name),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _Tag(
                                  icon: _methodIcon(p.method),
                                  text: authMethodLabel(p.method),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: p.id),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم نسخ رقم اللاعب'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: _Tag(
                                    icon: Icons.tag_rounded,
                                    text: p.id,
                                  ),
                                ),
                              ],
                            ),
                            if (p.contact != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    p.contact!,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'المستوى $level',
                          style: const TextStyle(
                            color: AppColors.bgTop,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: into / need),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 12,
                              backgroundColor: Colors.white12,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$into/$need',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (p.method == AuthMethod.guest) ...[
                    const SizedBox(height: 14),
                    BouncyButton(
                      tilt: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(link: true),
                        ),
                      ),
                      child: Container(
                        key: const ValueKey('link-account'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.quiz.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.quiz),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded, color: AppColors.quiz),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'أنت تلعب كضيف. اربط حسابك بجوجل أو رقم هاتفك حتى لا تخسر تقدمك',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_left_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn().slideY(begin: .1, end: 0),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  value: '${p.totalPlayed}',
                  label: 'مباراة',
                  icon: Icons.sports_esports_rounded,
                  color: AppColors.quiz,
                ),
                const SizedBox(width: 10),
                _Stat(
                  value: '${p.totalWins}',
                  label: 'فوز',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 10),
                _Stat(
                  value: p.totalPlayed == 0
                      ? '0%'
                      : '${(p.totalWins * 100 / p.totalPlayed).round()}%',
                  label: 'نسبة الفوز',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.seeko,
                ),
                const SizedBox(width: 10),
                _Stat(
                  value: '${p.coins}',
                  label: 'عملة',
                  iconWidget: const CoinIcon(size: 20),
                  color: AppColors.goldDeep,
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 14),
            const DailyRewardCard(),
            const SizedBox(height: 20),
            Text(
              'إحصائيات الألعاب',
              style: AppTheme.display.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 10),
            for (final (i, g) in GameRegistry.games.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    GlassCard(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: g.iconBuilder(context),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  g.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _MiniStat('${p.statsFor(g.id).played}', 'لعب'),
                              _MiniStat('${p.statsFor(g.id).wins}', 'فوز'),
                              _MiniStat('${p.statsFor(g.id).best}', 'أعلى'),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: (150 + i * 60).ms)
                        .slideX(begin: .1, end: 0),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'الإنجازات',
                  style: AppTheme.display.copyWith(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  '${p.unlocked.length}/${achievements.length}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .9,
              children: [
                for (final a in achievements)
                  _AchievementTile(a: a, unlocked: p.unlocked.contains(a.id)),
              ],
            ),
          ],
        );
      },
    );
  }

  static IconData _methodIcon(AuthMethod m) => switch (m) {
    AuthMethod.google => Icons.g_mobiledata_rounded,
    AuthMethod.phone => Icons.phone_iphone_rounded,
    AuthMethod.guest => Icons.person_outline_rounded,
  };

  Future<void> _rename(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'غيّر اسمك',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          key: const ValueKey('rename-field'),
          controller: ctrl,
          autofocus: true,
          maxLength: 18,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey('rename-save'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bgTop,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text(
              'حفظ',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (name != null) await Account.instance.rename(name);
  }

  void _pickAvatar(BuildContext context, int current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر صورتك',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < avatars.length; i++)
                  GestureDetector(
                    key: ValueKey('pick-avatar-$i'),
                    onTap: () {
                      Account.instance.setAvatar(i);
                      Navigator.pop(ctx);
                    },
                    child: PlayerAvatar(index: i, size: 60, ring: i == current),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة الهدية اليومية.
class DailyRewardCard extends StatelessWidget {
  const DailyRewardCard({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Account.instance,
    builder: (context, _) => _card(context),
  );

  Widget _card(BuildContext context) {
    final acc = Account.instance;
    final p = acc.profile!;
    final available = acc.dailyAvailable;
    return GlassCard(
      color: available ? AppColors.gold.withValues(alpha: .16) : null,
      child: Row(
        children: [
          Text(available ? '🎁' : '✅', style: const TextStyle(fontSize: 34))
              .animate(
                onPlay: (c) => available ? c.repeat(reverse: true) : null,
              )
              .scaleXY(begin: 1, end: available ? 1.15 : 1, duration: 700.ms),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الهدية اليومية',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  available
                      ? 'اجمعها كل يوم لتكبر (حتى 700 عملة)'
                      : 'رجع بكرة! السلسلة: ${p.dailyStreak} يوم',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (available)
            FilledButton(
              key: const ValueKey('claim-daily'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgTop,
              ),
              onPressed: () {
                final got = acc.claimDaily();
                if (got != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'حصلت على $got عملة! 🎉',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'اجمع',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
    this.iconWidget,
  });
  final String value;
  final String label;
  final Color color;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          iconWidget ?? Icon(icon, color: color),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.a, required this.unlocked});
  final Achievement a;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: a.description,
    triggerMode: TooltipTriggerMode.tap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.gold.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unlocked ? AppColors.gold : Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1 : .3,
            child: Text(a.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 4),
          Text(
            a.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              color: unlocked ? Colors.white : AppColors.textMuted,
            ),
          ),
          Text(
            a.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}
