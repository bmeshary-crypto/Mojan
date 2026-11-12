import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import '../games/game_registry.dart';
import '../widgets/animated_background.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/game_card.dart';
import '../widgets/mode_sheet.dart';
import 'splash_screen.dart';
import '../core/account/account.dart';
import '../widgets/account_widgets.dart';
import 'leaderboard_tab.dart';
import 'profile_tab.dart';
import 'rooms_tab.dart';
import 'settings_sheet.dart';
import 'shop_screen.dart';
import 'vip_screen.dart';
import '../core/vip.dart';
import 'support_screen.dart';
import '../widgets/daily_bonus.dart';

/// يظهر البونص اليومي تلقائياً مرة واحدة في كل تشغيل.
bool _dailyShown = false;

/// للاختبارات: إيقاف أو إعادة النافذة التلقائية للبونص.
@visibleForTesting
void debugSetDailyPopupShown(bool shown) => _dailyShown = shown;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dailyShown || !Account.instance.dailyAvailable) return;
      _dailyShown = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && Account.instance.dailyAvailable) showDailyBonus(context);
      });
    });
  }

  Future<void> _openGame(GameModule game) async {
    final mode = await showModeSheet(context, game);
    if (mode == null || !mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, _, _) => game.screenBuilder(context, mode),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : 2;

    return Scaffold(
      extendBody: true,
      body: AnimatedBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _TopBar(
                            onProfile: () => setState(() => _tab = 4),
                            onSettings: () => showSettingsSheet(context),
                            onShop: () => openShop(context),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
                        sliver: SliverToBoxAdapter(
                          child: _Hero(
                            onTap: () => _openGame(GameRegistry.games.first),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text(
                                'ألعابنا',
                                style: AppTheme.display.copyWith(fontSize: 28),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${GameRegistry.games.length}',
                                  style: const TextStyle(
                                    color: AppColors.bgTop,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  'والمزيد قريباً',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 200.ms),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: .78,
                              ),
                          itemCount: GameRegistry.games.length,
                          itemBuilder: (context, i) {
                            final g = GameRegistry.games[i];
                            return GameCard(
                              game: g,
                              index: i,
                              onTap: () => _openGame(g),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const _TabFrame(child: RoomsTab()),
              const _TabFrame(child: ShopScreen(embedded: true)),
              const _TabFrame(child: LeaderboardTab()),
              const _TabFrame(child: ProfileTab()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onProfile, required this.onSettings, required this.onShop});
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
          listenable: Account.instance,
          builder: (context, _) {
            final p = Account.instance.profile;
            return Row(
              children: [
                GestureDetector(
                  key: const ValueKey('top-avatar'),
                  onTap: onProfile,
                  child: PlayerAvatar(index: p?.avatar ?? 0, size: 50),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: GestureDetector(
                    onTap: onProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً يا ${p?.name ?? 'بطل'} 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'المستوى ${p?.level ?? 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              key: const ValueKey('top-vip'),
                              onTap: () => openVip(context),
                              child: (p?.vipLevel ?? 0) > 0
                                  ? VipBadge(p!.vipLevel, size: 10)
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.gold.withValues(alpha: .7)),
                                      ),
                                      child: const Text('VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.gold)),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BouncyButton(
                  tilt: false,
                  onTap: onShop,
                  child: Container(
                    key: const ValueKey('top-shop'),
                    padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .28),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: .5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _Coin()
                            .animate(onPlay: (c) => c.repeat())
                            .rotate(duration: 3.seconds, begin: 0, end: 1)
                            .then(),
                        const SizedBox(width: 6),
                        Text(
                          _fmt(p?.coins ?? 0),
                          key: const ValueKey('top-coins'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.add_circle_rounded, size: 18, color: AppColors.gold),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SupportBell(),
                const SizedBox(width: 8),
                BouncyButton(
                  tilt: false,
                  onTap: onSettings,
                  child: Container(
                    key: const ValueKey('top-settings'),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .28),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_rounded),
                  ),
                ),
              ],
            );
          },
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -.6, end: 0, curve: Curves.easeOutCubic);
  }

  static String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

/// إطار التبويبات بعرض أقصى ثابت.
class _TabFrame extends StatelessWidget {
  const _TabFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );
}

class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [Color(0xFFFFE08A), AppColors.gold, AppColors.goldDeep],
      ),
      border: Border.all(color: const Color(0xFFB86E00), width: 1.5),
    ),
    child: const Text(
      'M',
      style: TextStyle(
        fontFamily: 'Lalezar',
        fontSize: 13,
        color: Color(0xFF8A4B00),
        height: 1.25,
      ),
    ),
  );
}

/// بانر علوي فيه الشعار وزر "العب الآن".
class _Hero extends StatelessWidget {
  const _Hero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white.withValues(alpha: .14),
                Colors.white.withValues(alpha: .04),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: MojanWordmark(fontSize: 40),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'يلا نلعب! اختر لعبتك وتحدَّ أصحابك',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    BouncyButton(
                          tilt: false,
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFE08A),
                                  AppColors.gold,
                                  AppColors.goldDeep,
                                ],
                              ),
                              border: const Border(
                                bottom: BorderSide(
                                  color: Color(0xFFB86E00),
                                  width: 4,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: .5),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.bgTop,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'العب الآن',
                                  style: TextStyle(
                                    color: AppColors.bgTop,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                          begin: 1,
                          end: 1.05,
                          duration: 900.ms,
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),
              const MojanLogoMark(size: 96)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(
                    begin: -.03,
                    end: .03,
                    duration: 2400.ms,
                    curve: Curves.easeInOutSine,
                  )
                  .moveY(
                    begin: -4,
                    end: 4,
                    duration: 2400.ms,
                    curve: Curves.easeInOutSine,
                  ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 100.ms, duration: 500.ms)
        .scaleXY(begin: .92, end: 1, curve: Curves.easeOutBack);
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'الرئيسية'),
    (Icons.meeting_room_rounded, 'الغرف'),
    (Icons.storefront_rounded, 'المتجر'),
    (Icons.emoji_events_rounded, 'المتصدرون'),
    (Icons.person_rounded, 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final (i, (icon, label)) in _items.indexed)
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('nav-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: i == index ? AppColors.gold : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 22,
                              color: i == index
                                  ? AppColors.bgTop
                                  : AppColors.textMuted,
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: i == index
                                    ? AppColors.bgTop
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ).animate().slideY(
      begin: 1.2,
      end: 0,
      delay: 500.ms,
      duration: 600.ms,
      curve: Curves.easeOutBack,
    );
  }
}
