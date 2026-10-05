import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/dashboard_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../model/dashboard_model.dart';
import '../../model/permission_model.dart';
import '../../model/user_model.dart';
import '../../utils/responsive.dart';
import '../../viewmodel/access_viewmodel.dart';
import '../../widget/permission_guard.dart';
import '../profile_screen.dart';
import 'close_sfit_card.dart';
import 'dart:async';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashboardState state = ref.watch(dashboardViewModelProvider);
    final DashboardViewModel vm = ref.read(dashboardViewModelProvider.notifier);
    final UserModel? user = ref.watch(currentUserProvider);

    ref.listen<ShiftPhase>(
      shiftViewModelProvider.select((ShiftState s) => s.phase),
          (ShiftPhase? prev, ShiftPhase next) {
        final bool opened = prev == ShiftPhase.none && next == ShiftPhase.open;
        final bool closed = prev == ShiftPhase.open && next == ShiftPhase.none;
        if (opened || closed) vm.load(refresh: true);
      },
    );

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final bool wide = box.maxWidth >= 760;
          final bool m = context.isMobile;
          final double gap = m ? 12 : 15;

          return RefreshIndicator(
            onRefresh: () async {
              unawaited(ref.read(accessViewModelProvider.notifier).refresh());
              await vm.load(refresh: true);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 32 : 16,
                vertical: 10,
              ),
              child: ResponsiveCenter(
                maxWidth: Breakpoints.contentMaxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Header(
                      user: user,
                      onProfileTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                      ),
                      onEndShift: () {
                        if (ref.read(hasOpenShiftProvider)) {
                          showCloseShiftDialog(context);
                        } else {
                          AppUtils.showInfo('There is no active shift to end.');
                        }
                      },
                    ),
                    SizedBox(height: gap),
                    const ShiftStrip(),
                    SizedBox(height: gap),
                    _PeriodChips(
                      selected: state.period,
                      onChanged: vm.setPeriod,
                    ),
                    SizedBox(height: gap),
                    PermissionGuard(
                      permission: PermKey.dashboardView,
                      loading: _DashboardSkeleton(wide: wide),
                      child: _buildBody(state, vm, wide),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(DashboardState state, DashboardViewModel vm, bool wide) {
    if (state.isLoading) {
      return _DashboardSkeleton(wide: wide);
    }
    final DailySalesReport? report = state.report;
    if (report == null) {
      final failure = state.failure;
      return SizedBox(
        height: 360,
        child: failure == null
            ? const SizedBox.shrink()
            : AppErrorView(failure: failure, onRetry: () => vm.load()),
      );
    }
    return KeyedSubtree(
      key: ValueKey<DashboardPeriod>(state.period),
      child: _ReportBody(
        report: report,
        growth: state.growth,
        trend: state.trend,
        compareLabel: state.period.compareLabel,
        wide: wide,
      ),
    );
  }
}


String _inr(num value, {int decimals = 0}) {
  final List<String> parts = value.toStringAsFixed(decimals).split('.');
  String whole = parts[0];
  if (whole.length > 3) {
    final String last3 = whole.substring(whole.length - 3);
    final String rest = whole
        .substring(0, whole.length - 3)
        .replaceAllMapped(RegExp(r'(\d+?)(?=(\d{2})+$)'), (Match m) => '${m[1]},');
    whole = '$rest,$last3';
  }
  return '₹$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _greeting() {
  final int h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _pct(double v) {
  final String s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _pretty(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return t;
  if (t.length <= 3) return t.toUpperCase();
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

const List<Color> _fallbackColors = <Color>[
  AppColors.mintDark,
  AppColors.coral,
  Color(0xFF0E9FC4),
  AppColors.amber,
];

Color _paymentColor(String name, int index) {
  switch (name.toUpperCase()) {
    case 'CASH':
      return AppColors.primary;
    case 'UPI':
      return AppColors.sky;
    case 'COD':
      return AppColors.amber;
    default:
      return _fallbackColors[index % _fallbackColors.length];
  }
}

Color _channelColor(String name, int index) {
  switch (name.toUpperCase()) {
    case 'POS':
      return AppColors.primary;
    case 'ONLINE':
      return AppColors.sky;
    default:
      return _fallbackColors[index % _fallbackColors.length];
  }
}

class _Txt extends StatelessWidget {
  const _Txt(
      this.text,
      this.base, {
        required this.m,
        this.t,
        this.color,
        this.secondary = false,
        this.weight,
        this.maxLines,
        this.align,
        this.tabular = false,
      });

  final String text;
  final TextStyle base;

  /// Mobile font size.
  final double m;

  /// Tablet font size (null = mobile + 2).
  final double? t;
  final Color? color;
  final bool secondary;
  final FontWeight? weight;
  final int? maxLines;
  final TextAlign? align;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final double size = context.isTablet ? (t ?? m + 2) : m;
    return Text(
      text,
      maxLines: maxLines,
      textAlign: align,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: base.copyWith(
        fontSize: size,
        color: color ?? (secondary ? p.textSecondary : p.textPrimary),
        fontWeight: weight,
        fontFeatures: tabular
            ? const <FontFeature>[FontFeature.tabularFigures()]
            : null,
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.builder});

  final double value;
  final Widget Function(double v) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? _) => builder(v),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(m ? 14 : 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: m ? 16 : 24,
            offset: Offset(0, m ? 5 : 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: _Txt(text, AppTextStyles.body, m: 12, secondary: true),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.growth,
    required this.trend,
    required this.compareLabel,
    required this.wide,
  });

  final DailySalesReport report;
  final double? growth;
  final List<double>? trend;
  final String compareLabel;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    final double gap = m ? 12 : 16;
    final double sGap = m ? 10 : 16;

    final List<Widget> stats = <Widget>[
      _StatCard(
        icon: Icons.shopping_bag_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.primarySoft,
        label: 'Orders',
        value: _CountUp(
          value: report.totalOrders.toDouble(),
          builder: (double v) => _StatValue('${v.round()}'),
        ),
      ),
      _StatCard(
        icon: Icons.reply_rounded,
        iconColor: AppColors.coral,
        iconBg: AppColors.coralSoft,
        label: 'Refunds',
        value: _CountUp(
          value: report.totalRefunds,
          builder: (double v) => _StatValue(_inr(v, decimals: 2)),
        ),
      ),
      _StatCard(
        icon: Icons.paid_outlined,
        iconColor: const Color(0xFF0E9FC4),
        iconBg: AppColors.skySoft,
        label: 'Gross Sales',
        value: _CountUp(
          value: report.grossSales,
          builder: (double v) => _StatValue(_inr(v, decimals: 2)),
        ),
      ),
      _StatCard(
        icon: Icons.bar_chart_rounded,
        iconColor: const Color(0xFFE08A00),
        iconBg: AppColors.amberSoft,
        label: 'Avg Order',
        value: _CountUp(
          value: report.avgOrderValue,
          builder: (double v) => _StatValue(_inr(v)),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _NetSalesCard(
          netSales: report.netSales,
          growth: growth,
          trend: trend,
          compareLabel: compareLabel,
        ),
        SizedBox(height: gap),
        if (wide)
          Row(
            children: <Widget>[
              for (int i = 0; i < stats.length; i++) ...<Widget>[
                if (i > 0) SizedBox(width: sGap),
                Expanded(child: stats[i]),
              ],
            ],
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(child: stats[0]),
              SizedBox(width: sGap),
              Expanded(child: stats[1]),
            ],
          ),
          SizedBox(height: sGap),
          Row(
            children: <Widget>[
              Expanded(child: stats[2]),
              SizedBox(width: sGap),
              Expanded(child: stats[3]),
            ],
          ),
        ],
        SizedBox(height: gap),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _ChannelCard(channels: report.channelBreakdown)),
              const SizedBox(width: 16),
              Expanded(child: _PaymentCard(report: report)),
            ],
          )
        else ...<Widget>[
          _ChannelCard(channels: report.channelBreakdown),
          SizedBox(height: gap),
          _PaymentCard(report: report),
        ],
        SizedBox(height: gap),
        _CashiersCard(cashiers: report.cashierBreakdown),
        const SizedBox(height: 24),
      ],
    );
  }
}


class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onEndShift,
    required this.onProfileTap,
  });

  final UserModel? user;
  final VoidCallback onEndShift;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    final String name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'User';
    final String role = (user?.roleName.trim().isNotEmpty ?? false)
        ? user!.roleName.trim().toUpperCase()
        : 'USER';

    return Row(
      children: <Widget>[
        // Profile area: avatar + greeting + name + role (tap = profile screen)
        Expanded(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onProfileTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: m ? 39 : 50,
                      height: m ? 39 : 50,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: _Txt(
                        name.substring(0, 1).toUpperCase(),
                        AppTextStyles.h2,
                        m: 15,
                        t: 19,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: m ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _Txt(
                            _greeting(),
                            AppTextStyles.body,
                            m: 12,
                            t: 14,
                            secondary: true,
                          ),
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: _Txt(
                                  name,
                                  AppTextStyles.title,
                                  m: 15,
                                  t: 18,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primarySoft,
                                  borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  role,
                                  style: AppTextStyles.label.copyWith(
                                    color: palette.isDark
                                        ? AppColors.primaryLight
                                        : AppColors.primary,
                                    fontSize: m ? 9 : 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: m ? 18 : 20,
                      color: palette.textHint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // End shift button (pehle jaisa)
        Material(
          color: palette.isDark
              ? AppColors.coral.withAlpha(30)
              : AppColors.coralSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onEndShift,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: m ? 10 : 12,
                vertical: m ? 9 : 11,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.logout_rounded,
                    size: m ? 14 : 16,
                    color: AppColors.coral,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'End shift',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.coral,
                      fontSize: m ? 11 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.selected, required this.onChanged});

  final DashboardPeriod selected;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final DashboardPeriod p in DashboardPeriod.values) ...<Widget>[
            if (p != DashboardPeriod.values.first) SizedBox(width: m ? 8 : 10),
            GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: m ? 16 : 20,
                  vertical: m ? 9 : 12,
                ),
                decoration: BoxDecoration(
                  color: p == selected ? AppColors.primary : palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: p == selected
                      ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  p.label,
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: m ? 12 : 14,
                    color: p == selected ? Colors.white : palette.textSecondary,
                    fontWeight:
                    p == selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetSalesCard extends StatelessWidget {
  const _NetSalesCard({
    required this.netSales,
    required this.growth,
    required this.trend,
    required this.compareLabel,
  });

  final double netSales;
  final double? growth;

  /// Sparkline points (net sales per bucket). Null ho to chart nahi dikhta.
  final List<double>? trend;
  final String compareLabel;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    final double? g = growth;
    final bool up = (g ?? 0) >= 0;
    final List<double>? points = trend;

    return Container(
      height: m ? 168 : 212,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(m ? 22 : AppRadius.xxl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: m ? 18 : 24,
            offset: Offset(0, m ? 7 : 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Sparkline: left se draw hoti hai (real trend aane par).
          if (points != null && points.length >= 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: m ? 84 : 110,
              child: _Sparkline(values: points),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              m ? 16 : 20,
              m ? 14 : 18,
              m ? 16 : 20,
              m ? 12 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _Txt(
                      'Net Sales',
                      AppTextStyles.body,
                      m: 12,
                      t: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const Spacer(),
                    if (g != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: m ? 9 : 12,
                          vertical: m ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: up ? AppColors.mint : AppColors.coral,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              up
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: m ? 12 : 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            _Txt(
                              '${_pct(g.abs())}%',
                              AppTextStyles.bodyBold,
                              m: 11,
                              t: 13,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: m ? 2 : 4),
                _CountUp(
                  value: netSales,
                  builder: (double v) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _Txt(
                      _inr(v, decimals: 2),
                      AppTextStyles.hero,
                      m: 20,
                      t: 28,
                      color: Colors.white,
                      tabular: true,
                    ),
                  ),
                ),
                const Spacer(),
                _Txt(
                  g == null ? 'Net sales for selected period' : compareLabel,
                  AppTextStyles.caption,
                  m: 11,
                  t: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final double maxValue = values.reduce(math.max);
    final double minValue = values.reduce(math.min);
    final double range = maxValue - minValue;
    final double pad = range > 0
        ? range * 0.25
        : (maxValue.abs() > 0 ? maxValue.abs() * 0.5 : 1);
    final double minY = minValue - pad;
    final double maxY = maxValue + pad;

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(Object.hashAll(values)),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) {
        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (values.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: <FlSpot>[
                  for (int i = 0; i < values.length; i++)
                    FlSpot(i.toDouble(), minY + (values[i] - minY) * t),
                ],
                isCurved: true,
                curveSmoothness: 0.33,
                preventCurveOverShooting: true,
                color: Colors.white,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}


class _StatValue extends StatelessWidget {
  const _StatValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: _Txt(
        text,
        AppTextStyles.h1,
        m: 17,
        t: 22,
        weight: FontWeight.w800,
        tabular: true,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final bool m = context.isMobile;

    return _Card(
      padding: EdgeInsets.all(m ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: m ? 34 : 40,
                height: m ? 34 : 40,
                decoration: BoxDecoration(
                  color: dark ? iconColor.withAlpha(36) : iconBg,
                  borderRadius: BorderRadius.circular(m ? 11 : 14),
                ),
                child: Icon(icon, color: iconColor, size: m ? 18 : 22),
              ),
              const Spacer(),
              _Txt(label, AppTextStyles.body, m: 12, t: 14, secondary: true),
            ],
          ),
          SizedBox(height: m ? 10 : 14),
          value,
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channels});

  final Map<String, ChannelSales> channels;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    final List<MapEntry<String, ChannelSales>> entries = channels.entries.toList();
    final int totalCount = entries.fold<int>(
      0,
          (int s, MapEntry<String, ChannelSales> e) => s + e.value.count,
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Txt('Sales by Channel', AppTextStyles.title, m: 14, t: 16),
              const Spacer(),
              GestureDetector(
                onTap: () => AppUtils.showInfo('Coming soon'),
                child: _Txt(
                  'View all',
                  AppTextStyles.bodyBold,
                  m: 12,
                  t: 13,
                  color: context.palette.isDark
                      ? AppColors.primaryLight
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: m ? 12 : 16),
          if (entries.isEmpty)
            const _EmptyNote('No channel sales yet')
          else
            for (int i = 0; i < entries.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: m ? 12 : 16),
              _ChannelRow(
                name: _pretty(entries[i].key),
                orders: entries[i].value.count,
                amount: entries[i].value.total,
                fraction: totalCount == 0 ? 0 : entries[i].value.count / totalCount,
                color: _channelColor(entries[i].key, i),
              ),
            ],
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.name,
    required this.orders,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  final String name;
  final int orders;
  final double amount;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Txt(name, AppTextStyles.bodyBold, m: 13, t: 15),
            const SizedBox(width: 6),
            _Txt('$orders orders', AppTextStyles.body, m: 11, t: 13, secondary: true),
            const Spacer(),
            _CountUp(
              value: amount,
              builder: (double v) =>
                  _Txt(_inr(v), AppTextStyles.bodyBold, m: 13, t: 15),
            ),
          ],
        ),
        SizedBox(height: m ? 6 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: m ? 7 : 10,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: palette.surfaceAlt)),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double v, Widget? _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _PaymentSlice {
  const _PaymentSlice(this.name, this.amount, this.percent, this.color);
  final String name;
  final double amount;
  final double percent;
  final Color color;
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.report});

  final DailySalesReport report;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final double total = report.paymentTotal;

    final List<MapEntry<String, double>> entries =
    report.paymentBreakdown.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));

    final List<_PaymentSlice> slices = <_PaymentSlice>[
      for (int i = 0; i < entries.length; i++)
        _PaymentSlice(
          _pretty(entries[i].key),
          entries[i].value,
          total <= 0 ? 0 : entries[i].value / total * 100,
          _paymentColor(entries[i].key, i),
        ),
    ];

    final double chart = m ? 112 : 150;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Txt('Payment Methods', AppTextStyles.title, m: 14, t: 16),
          SizedBox(height: m ? 12 : 16),
          if (slices.isEmpty || total <= 0)
            const _EmptyNote('No payments yet')
          else
            Row(
              children: <Widget>[
                SizedBox(
                  width: chart,
                  height: chart,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double t, Widget? _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          PieChart(
                            PieChartData(
                              startDegreeOffset: -90,
                              sectionsSpace: 2,
                              centerSpaceRadius: m ? 40 : 54,
                              pieTouchData: PieTouchData(enabled: false),
                              borderData: FlBorderData(show: false),
                              sections: <PieChartSectionData>[
                                for (final _PaymentSlice p in slices)
                                  PieChartSectionData(
                                    value: math.max(p.percent, 0.5) * t,
                                    color: p.color,
                                    radius: m ? 13 : 18,
                                    showTitle: false,
                                  ),
                                // Khali hissa: isse donut clockwise bharta hai.
                                if (t < 1)
                                  PieChartSectionData(
                                    value: 100 * (1 - t),
                                    color: Colors.transparent,
                                    radius: m ? 13 : 18,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                            duration: Duration.zero,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _Txt(
                                '${(report.totalOrders * t).round()}',
                                AppTextStyles.h2,
                                m: 17,
                                t: 22,
                                weight: FontWeight.w800,
                              ),
                              Text(
                                'ORDERS',
                                style: AppTextStyles.caption.copyWith(
                                  color: palette.textSecondary,
                                  fontSize: m ? 9 : 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(width: m ? 16 : 20),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      for (final _PaymentSlice p in slices)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: m ? 5 : 7),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: p.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _Txt(p.name, AppTextStyles.body, m: 12, t: 14, maxLines: 1),
                                    _Txt(
                                      _inr(p.amount),
                                      AppTextStyles.caption,
                                      m: 10,
                                      t: 11,
                                      secondary: true,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              _Txt('${_pct(p.percent)}%', AppTextStyles.bodyBold, m: 12, t: 14),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CashiersCard extends StatelessWidget {
  const _CashiersCard({required this.cashiers});

  final List<CashierSales> cashiers;

  static const List<List<Color>> _tones = <List<Color>>[
    <Color>[AppColors.primarySoft, AppColors.primary],
    <Color>[AppColors.skySoft, Color(0xFF0E9FC4)],
    <Color>[AppColors.mintSoft, AppColors.mintDark],
    <Color>[AppColors.amberSoft, Color(0xFFE08A00)],
  ];

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final bool m = context.isMobile;

    final List<CashierSales> sorted = List<CashierSales>.of(cashiers)
      ..sort((CashierSales a, CashierSales b) => b.totalSales.compareTo(a.totalSales));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Txt('Top Cashiers', AppTextStyles.title, m: 14, t: 16),
          SizedBox(height: m ? 8 : 12),
          if (sorted.isEmpty)
            const _EmptyNote('No cashier sales yet')
          else
            for (int i = 0; i < sorted.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: m ? 6 : 8),
                child: Row(
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: m ? 40 : 50,
                          height: m ? 40 : 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: dark
                                ? _tones[i % _tones.length][1].withAlpha(36)
                                : _tones[i % _tones.length][0],
                            shape: BoxShape.circle,
                          ),
                          child: _Txt(
                            _initials(sorted[i].name),
                            AppTextStyles.title,
                            m: 13,
                            t: 16,
                            weight: FontWeight.w700,
                            color: _tones[i % _tones.length][1],
                          ),
                        ),
                        if (i == 0)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: m ? 16 : 20,
                              height: m ? 16 : 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.palette.surface,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '1',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: m ? 8 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: m ? 12 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _Txt(sorted[i].name, AppTextStyles.bodyBold, m: 13, t: 15, maxLines: 1),
                          _Txt(
                            '${sorted[i].orderCount} orders',
                            AppTextStyles.caption,
                            m: 11,
                            t: 12,
                            secondary: true,
                          ),
                        ],
                      ),
                    ),
                    _CountUp(
                      value: sorted[i].totalSales,
                      builder: (double v) =>
                          _Txt(_inr(v), AppTextStyles.bodyBold, m: 13, t: 15),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}


class _Shim extends StatelessWidget {
  const _Shim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF262A4A) : const Color(0xFFE7E5F1),
      highlightColor: dark ? const Color(0xFF353A63) : const Color(0xFFF7F6FC),
      child: child,
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    final double gap = m ? 12 : 16;
    final double sGap = m ? 10 : 16;

    Widget stat() => _Card(
      padding: EdgeInsets.all(m ? 12 : 16),
      child: _Shim(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Bone(width: m ? 34 : 44, height: m ? 34 : 44, radius: 12),
                const Spacer(),
                const _Bone(width: 48, height: 10),
              ],
            ),
            SizedBox(height: m ? 12 : 16),
            _Bone(width: m ? 80 : 110, height: m ? 16 : 20),
          ],
        ),
      ),
    );

    Widget listCard({required int rows, bool avatar = false}) => _Card(
      child: _Shim(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Bone(width: 120, height: 14),
            SizedBox(height: m ? 14 : 18),
            for (int i = 0; i < rows; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 14),
              if (avatar)
                Row(
                  children: <Widget>[
                    _Bone(width: m ? 40 : 50, height: m ? 40 : 50, radius: 40),
                    const SizedBox(width: 12),
                    const Expanded(child: _Bone(height: 12)),
                    const SizedBox(width: 20),
                    const _Bone(width: 56, height: 12),
                  ],
                )
              else ...<Widget>[
                const Row(
                  children: <Widget>[
                    _Bone(width: 70, height: 12),
                    Spacer(),
                    _Bone(width: 60, height: 12),
                  ],
                ),
                const SizedBox(height: 8),
                const _Bone(height: 8, radius: 20),
              ],
            ],
          ],
        ),
      ),
    );

    final Widget channel = listCard(rows: 2);
    final Widget payment = _Card(
      child: _Shim(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Bone(width: 130, height: 14),
            SizedBox(height: m ? 14 : 18),
            Row(
              children: <Widget>[
                _Bone(width: m ? 100 : 130, height: m ? 100 : 130, radius: 100),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    children: <Widget>[
                      _Bone(height: 12),
                      SizedBox(height: 14),
                      _Bone(height: 12),
                      SizedBox(height: 14),
                      _Bone(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Card(
          child: _Shim(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Bone(width: 70, height: 12),
                SizedBox(height: m ? 12 : 16),
                _Bone(width: m ? 190 : 260, height: m ? 28 : 36, radius: 10),
                SizedBox(height: m ? 12 : 16),
                const _Bone(width: 100, height: 10),
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        if (wide)
          Row(
            children: <Widget>[
              for (int i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) SizedBox(width: sGap),
                Expanded(child: stat()),
              ],
            ],
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(child: stat()),
              SizedBox(width: sGap),
              Expanded(child: stat()),
            ],
          ),
          SizedBox(height: sGap),
          Row(
            children: <Widget>[
              Expanded(child: stat()),
              SizedBox(width: sGap),
              Expanded(child: stat()),
            ],
          ),
        ],
        SizedBox(height: gap),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: channel),
              const SizedBox(width: 16),
              Expanded(child: payment),
            ],
          )
        else ...<Widget>[
          channel,
          SizedBox(height: gap),
          payment,
        ],
        SizedBox(height: gap),
        listCard(rows: 3, avatar: true),
        const SizedBox(height: 24),
      ],
    );
  }
}