import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../utils/responsive.dart';
import '../history_screen.dart';
import '../home/dashboard_screen.dart';
import '../product/product_screen.dart';

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

  final List<Widget> _pages = const <Widget>[
    DashboardScreen(),
    _ComingSoon(title: 'Held Sales'),
    _ComingSoon(title: 'New Sale'),
    HistoryScreen(),
    ProductListScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool tablet = context.isTablet;

    final Widget content = IndexedStack(index: _index, children: _pages);

    return PopScope(
      // Back dabane par pehle Home tab pe jao, phir app band ho.
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) setState(() => _index = 0);
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
              : content,
          bottomNavigationBar: tablet
              ? null
              : _BottomBar(index: _index, onTap: _select),
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
  static const double _sellSize = 60;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

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
          // Sell button (bar ke upar, hit-test ke liye Stack ke andar hi hai)
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
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 34,
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
                size: 24,
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

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.construction_rounded,
                size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.h2.copyWith(
              color: context.palette.textPrimary,
            )),
            const SizedBox(height: 4),
            Text(
              'Coming soon',
              style: AppTextStyles.body
                  .copyWith(color: context.palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}