import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../utils/responsive.dart';
import '../../widget/app_textfield.dart';
import '../model/pos_history_model.dart';
import '../viewmodel/pos_history_viewmodel.dart';

// ═══════════════════════════════════════════════════════════════════════════
// UI helpers (colors / icons). Model me UI nahi, isliye yahan extension.
// ═══════════════════════════════════════════════════════════════════════════

const Color _amberText = Color(0xFFE08A00);
const Color _skyText = Color(0xFF0E9FC4);

extension on PayMethod {
  IconData get icon {
    switch (this) {
      case PayMethod.cash:
        return Icons.payments_outlined;
      case PayMethod.upi:
        return Icons.qr_code_2_rounded;
      case PayMethod.cod:
        return Icons.local_shipping_outlined;
      case PayMethod.card:
        return Icons.credit_card_rounded;
      case PayMethod.other:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color get color {
    switch (this) {
      case PayMethod.cash:
        return AppColors.primary;
      case PayMethod.upi:
        return _skyText;
      case PayMethod.cod:
        return _amberText;
      case PayMethod.card:
        return AppColors.mintDark;
      case PayMethod.other:
        return AppColors.primary;
    }
  }

  Color get soft {
    switch (this) {
      case PayMethod.cash:
        return AppColors.primarySoft;
      case PayMethod.upi:
        return AppColors.skySoft;
      case PayMethod.cod:
        return AppColors.amberSoft;
      case PayMethod.card:
        return AppColors.mintSoft;
      case PayMethod.other:
        return AppColors.primarySoft;
    }
  }
}

class _StatusLook {
  const _StatusLook(this.color, this.background);

  final Color color;
  final Color background;
}

_StatusLook _statusLook(OrderStatus status, AppPalette palette) {
  final bool dark = palette.isDark;
  switch (status) {
    case OrderStatus.completed:
      return _StatusLook(
        dark ? AppColors.mint : AppColors.mintDark,
        dark ? AppColors.mint.withAlpha(30) : AppColors.mintSoft,
      );
    case OrderStatus.pending:
      return _StatusLook(
        _amberText,
        dark ? AppColors.amber.withAlpha(30) : AppColors.amberSoft,
      );
    case OrderStatus.refunded:
      return _StatusLook(
        AppColors.coral,
        dark ? AppColors.coral.withAlpha(30) : AppColors.coralSoft,
      );
    case OrderStatus.cancelled:
    case OrderStatus.unknown:
      return _StatusLook(palette.textSecondary, palette.surfaceAlt);
  }
}

/// 1245 -> ₹1,245 , 8950.5 -> ₹8,950.50 , 124500 -> ₹1,24,500
String _inr(double value) {
  final bool whole = value % 1 == 0;
  final List<String> parts = value.toStringAsFixed(whole ? 0 : 2).split('.');
  String digits = parts[0];
  if (digits.length > 3) {
    final String last3 = digits.substring(digits.length - 3);
    final String rest = digits
        .substring(0, digits.length - 3)
        .replaceAllMapped(RegExp(r'(\d+?)(?=(\d{2})+$)'), (Match m) => '${m[1]},');
    digits = '$rest,$last3';
  }
  return '₹$digits${parts.length > 1 ? '.${parts[1]}' : ''}';
}

final DateFormat _dateFormat = DateFormat('dd MMM, hh:mm a');

String _dateText(DateTime? date) =>
    date == null ? '' : _dateFormat.format(date.toLocal());

const SliverGridDelegateWithMaxCrossAxisExtent _gridDelegate =
SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 480,
  mainAxisExtent: 136,
  mainAxisSpacing: 12,
  crossAxisSpacing: 14,
);

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Neeche se 320px pehle hi agla page mangwa lo, user ko wait na dikhe.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final ScrollPosition p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 320) {
      ref.read(orderHistoryViewModelProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    final ApiResult<PosOrderPage> result =
    await ref.read(orderHistoryViewModelProvider.notifier).refresh();
    // Fail hua to server ka message bubble mein, purani list screen par rahegi.
    if (result is ApiFailure<PosOrderPage>) {
      AppUtils.showFailure(result.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrderHistoryState s = ref.watch(orderHistoryViewModelProvider);
    final OrderHistoryViewModel vm =
    ref.read(orderHistoryViewModelProvider.notifier);

    final bool firstLoad = s.isLoading && s.orders.isEmpty;
    final bool errorOnly = !s.isLoading && s.failure != null && s.orders.isEmpty;
    final List<PosOrder> visible = s.visible;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double pad = box.maxWidth >= 760 ? 32 : 20;

          Widget body;
          if (firstLoad) {
            body = _SkeletonGrid(padding: pad);
          } else if (errorOnly) {
            body = AppErrorView(failure: s.failure!, onRetry: vm.reload);
          } else {
            body = RefreshIndicator(
              onRefresh: _onRefresh,
              child: visible.isEmpty
                  ? _EmptyView(
                // Filter lagne se khali dikhe par aur pages baaki ho sakte hain.
                canLoadMore: s.hasMore,
                isLoadingMore: s.isLoadingMore,
                onLoadMore: vm.loadMore,
              )
                  : CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
                    sliver: SliverGrid(
                      gridDelegate: _gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int i) =>
                            _OrderCard(order: visible[i]),
                        childCount: visible.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _ListFooter(
                      isLoadingMore: s.isLoadingMore,
                      failure: s.loadMoreFailure,
                      hasMore: s.hasMore,
                      onLoadMore: vm.loadMore,
                      onRetry: () => vm.loadMore(retry: true),
                    ),
                  ),
                ],
              ),
            );
          }

          return ResponsiveCenter(
            maxWidth: Breakpoints.contentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const AppText.h1('Order History'),
                      const SizedBox(height: 2),
                      AppText.body(
                        firstLoad
                            ? 'Loading orders…'
                            : '${s.total > 0 ? s.total : s.orders.length} orders',
                        secondary: true,
                      ),
                      const SizedBox(height: 16),
                      AppTextField.search(
                        controller: _search,
                        hint: 'Search by order, customer or cashier',
                        onChanged: vm.setQuery,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _FilterChips(
                  padding: pad,
                  selected: s.filter,
                  // Load hone tak ya aur pages baaki hone par count nahi dikhate.
                  countOf: firstLoad ? null : s.countOf,
                  onChanged: vm.setFilter,
                ),
                const SizedBox(height: 14),
                Expanded(child: body),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter chips
// ═══════════════════════════════════════════════════════════════════════════

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.padding,
    required this.selected,
    required this.countOf,
    required this.onChanged,
  });

  final double padding;
  final OrderFilter selected;

  /// null = count nahi dikhana. Function null de to bhi count nahi dikhega.
  final int? Function(OrderFilter)? countOf;
  final ValueChanged<OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: <Widget>[
          for (final OrderFilter f in OrderFilter.values) ...<Widget>[
            if (f != OrderFilter.all) const SizedBox(width: 10),
            GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: f == selected ? AppColors.primary : palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: f == selected
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
                  _chipText(f),
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 13,
                    color:
                    f == selected ? Colors.white : palette.textSecondary,
                    fontWeight:
                    f == selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _chipText(OrderFilter f) {
    final int? count = countOf?.call(f);
    return count == null ? f.label : '${f.label} ($count)';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Order card
// ═══════════════════════════════════════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PosOrder order;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = palette.isDark;
    final _StatusLook status = _statusLook(order.status, palette);

    // Payment: ek mode ho to uska icon/rang, split ho to alag icon.
    final PayMethod? method = order.primaryMethod;
    final bool split = order.isSplit;
    final IconData payIcon = split
        ? Icons.call_split_rounded
        : (method?.icon ?? Icons.payments_outlined);
    final Color payColor =
    split ? AppColors.primary : (method?.color ?? palette.textSecondary);
    final Color paySoft = split
        ? AppColors.primarySoft
        : (method?.soft ?? palette.surfaceAlt);

    final TextStyle amountStyle = AppTextStyles.bodyBold.copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      color: order.status == OrderStatus.refunded
          ? AppColors.coral
          : order.status == OrderStatus.cancelled
          ? palette.textHint
          : palette.textPrimary,
      decoration: order.status == OrderStatus.cancelled
          ? TextDecoration.lineThrough
          : null,
    );

    final String items =
        '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}';
    final String when = _dateText(order.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Payment method icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: dark ? payColor.withAlpha(36) : paySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(payIcon, color: payColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppText.bodyBold(order.orderNumber, maxLines: 1),
                    ),
                    const SizedBox(width: 8),
                    Text(_inr(order.total), style: amountStyle),
                  ],
                ),
                const SizedBox(height: 2),
                AppText.caption(
                  when.isEmpty ? items : '$when  •  $items',
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(Icons.person_outline_rounded,
                        size: 15, color: palette.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AppText.caption(order.customerName, maxLines: 1),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      label: order.statusLabel,
                      color: status.color,
                      background: status.background,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(Icons.badge_outlined,
                        size: 15, color: palette.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AppText.caption(
                        'Cashier: ${order.cashierName}',
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      label: order.paymentLabel,
                      color: payColor,
                      background: dark ? payColor.withAlpha(30) : paySoft,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Footer (load more / retry / end of list) + empty view
// ═══════════════════════════════════════════════════════════════════════════

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.isLoadingMore,
    required this.failure,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
  });

  final bool isLoadingMore;
  final Failure? failure;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isLoadingMore) {
      child = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 3, strokeCap: StrokeCap.round),
        ),
      );
    } else if (failure != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppText.body(failure!.message, align: TextAlign.center, secondary: true),
          const SizedBox(height: 10),
          AppButton(
            label: 'Retry',
            leadingIcon: Icons.refresh_rounded,
            variant: AppButtonVariant.tonal,
            size: AppButtonSize.small,
            fullWidth: false,
            onPressed: onRetry,
          ),
        ],
      );
    } else if (hasMore) {
      // Filter se list chhoti ho to scroll hi nahi hoga, isliye button bhi.
      child = AppButton(
        label: 'Load more orders',
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.small,
        fullWidth: false,
        onPressed: onLoadMore,
      );
    } else {
      child = const AppText.caption('You have reached the end');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Center(child: child),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.canLoadMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final bool canLoadMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    // ListView: taaki khali list pe bhi pull-to-refresh chale.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 60),
        Icon(Icons.receipt_long_outlined,
            size: 48, color: context.palette.textHint),
        const SizedBox(height: 12),
        const AppText.title('No orders found', align: TextAlign.center),
        const SizedBox(height: 4),
        const AppText.body(
          'Try a different search or filter.',
          align: TextAlign.center,
          secondary: true,
        ),
        if (canLoadMore) ...<Widget>[
          const SizedBox(height: 16),
          Center(
            child: AppButton(
              label: 'Search older orders',
              variant: AppButtonVariant.tonal,
              size: AppButtonSize.small,
              fullWidth: false,
              isLoading: isLoadingMore,
              onPressed: onLoadMore,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Loading skeleton (shimmer). API ke time yehi dikhega.
// ═══════════════════════════════════════════════════════════════════════════

class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid({required this.padding});

  final double padding;

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  // Ek hi controller poori grid ke liye, isliye shimmer smooth aur halka.
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(widget.padding, 0, widget.padding, 24),
      gridDelegate: _gridDelegate,
      itemCount: 8,
      itemBuilder: (BuildContext context, int i) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: palette.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: <Widget>[
              _Bone(anim: _anim, width: 48, height: 48, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _Bone(anim: _anim, width: 110, height: 14),
                        const Spacer(),
                        _Bone(anim: _anim, width: 60, height: 14),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Bone(anim: _anim, width: 130, height: 10),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        _Bone(anim: _anim, width: 96, height: 11),
                        const Spacer(),
                        _Bone(anim: _anim, width: 62, height: 18, radius: 9),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        _Bone(anim: _anim, width: 110, height: 11),
                        const Spacer(),
                        _Bone(anim: _anim, width: 44, height: 18, radius: 9),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer wala ek skeleton block.
class _Bone extends StatelessWidget {
  const _Bone({
    required this.anim,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final Animation<double> anim;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color base = palette.isDark ? palette.surfaceAlt : palette.border;
    final Color highlight = palette.isDark ? palette.border : palette.surfaceAlt;

    return AnimatedBuilder(
      animation: anim,
      builder: (BuildContext context, Widget? _) {
        final double shift = -2 + 4 * anim.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(shift - 1, 0),
              end: Alignment(shift + 1, 0),
              colors: <Color>[base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}