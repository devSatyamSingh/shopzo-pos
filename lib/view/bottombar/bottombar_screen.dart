import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../utils/responsive.dart';
import '../held/held_screen.dart';
import '../history/history_screen.dart';
import '../home/dashboard_screen.dart';
import '../product/product_screen.dart';
import '../sell/sell_screen.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const List<_NavItem> _items = <_NavItem>[
  _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
  _NavItem('Held', Icons.pause_circle_outline_rounded, Icons.pause_circle_rounded),
  _NavItem('Sell', Icons.add_rounded, Icons.add_rounded),
  _NavItem('History', Icons.history_rounded, Icons.history_rounded),
  _NavItem('Products', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
];

const int _sellIndex = 2;

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;
  bool _exitOpen = false;

  late final List<Widget> _pages = <Widget>[
    const DashboardScreen(),
    HeldScreen(onResumed: () => _select(_sellIndex)), // resume ke baad Sell tab
    const SellScreen(),
    const HistoryScreen(),
    const ProductListScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }


  Future<void> _onBack() async {
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    if (_exitOpen) return;
    _exitOpen = true;
    HapticFeedback.mediumImpact();

    final bool? exit = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Exit',
      barrierColor: AppColors.overlay,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) =>
      const _ExitDialog(),
      transitionBuilder: (BuildContext c, Animation<double> anim,
          Animation<double> sec, Widget child) {
        final Animation<double> curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(curved),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );

    _exitOpen = false;
    if (exit == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool tablet = context.isTablet;
    final bool keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    final Widget content = IndexedStack(index: _index, children: _pages);

    // Phone: bar body ke Stack me hai. Content sirf bar ki height tak aata hai
    // (koi extra gap nahi), Sell button content ke upar float karta hai.
    final Widget phoneBody = Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Expanded(child: content),
            if (!keyboard)
              SizedBox(height: _BottomBar._barHeight + bottomInset),
          ],
        ),
        if (!keyboard)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(index: _index, onTap: _select),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _onBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: palette.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: palette.background,
          body: tablet
              ? Row(
            children: <Widget>[
              SafeArea(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  backgroundColor: palette.surface,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: palette.primarySoft,
                  selectedIconTheme:
                  const IconThemeData(color: AppColors.primary),
                  unselectedIconTheme:
                  IconThemeData(color: palette.textHint),
                  selectedLabelTextStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: AppTextStyles.caption
                      .copyWith(color: palette.textHint),
                  destinations: <NavigationRailDestination>[
                    for (final _NavItem item in _items)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.activeIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: palette.border),
              Expanded(child: content),
            ],
          )
              : phoneBody,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Exit popup (animated bubble)
// ═══════════════════════════════════════════════════════════════════════════

class _ExitDialog extends StatelessWidget {
  const _ExitDialog();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.border.withValues(alpha: 0.6)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.coral.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Icon bubble: bounce ke saath aata hai.
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (BuildContext c, double t, Widget? child) =>
                      Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? AppColors.coral.withAlpha(36)
                          : AppColors.coralSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 32,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Exit app?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to close the app?',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: palette.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: 'Stay',
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.medium,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Exit',
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.medium,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom bar (phone): beech mein upar uthta hua Sell button
// ═══════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const double _barHeight = 64;
  static const double _lift = 28; // button bar ke upar kitna nikla rahe
  static const double _sellSize = 50;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    // Upar ka _lift hissa transparent hai: touch niche content tak jaate hain,
    // sirf Sell button apna tap leta hai.
    return SizedBox(
      height: _barHeight + _lift + bottomInset,
      child: Stack(
        children: <Widget>[
          // Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottomInset,
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < _items.length; i++)
                    Expanded(
                      child: i == _sellIndex
                          ? const _SellLabel()
                          : _NavTile(
                        item: _items[i],
                        selected: i == index,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Sell button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _sellSize,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Sell',
                child: GestureDetector(
                  onTap: () => onTap(_sellIndex),
                  child: Container(
                    width: _sellSize,
                    height: _sellSize,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.40),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellLabel extends StatelessWidget {
  const _SellLabel();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'Sell',
          style: AppTextStyles.caption.copyWith(
            color: context.palette.isDark
                ? AppColors.primaryLight
                : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color color = selected
        ? (palette.isDark ? AppColors.primaryLight : AppColors.primary)
        : palette.textHint;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.1 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}