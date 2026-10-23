import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/pos_history_model.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/sell/pos_card.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_shimmer.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../viewmodel/pos_history_viewmodel.dart';
import 'exchange_flow_screen.dart';

Future<bool?> openExchange(BuildContext context, PosOrder order) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ExchangeFlowScreen(order: order),
    ),
  );
}

class ExchangeButton extends StatelessWidget {
  const ExchangeButton({super.key, required this.order});

  final PosOrder order;

  @override
  Widget build(BuildContext context) {
    if (!order.canExchange) return const SizedBox.shrink();

    final AppPalette palette = context.palette;
    final Color tone =
    palette.isDark ? AppColors.primaryLight : AppColors.primary;

    return Material(
      color: palette.primarySoft,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => openExchange(context, order),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.swap_horiz_rounded, size: 18, color: tone),
              const SizedBox(width: 6),
              Text(
                'Exchange',
                style: AppTextStyles.bodyBold.copyWith(
                  fontSize: 13,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Exchange list (Profile -> Exchange)
// ═══════════════════════════════════════════════════════════════════════════

class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key});

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _query = '';

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

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 300) {
      ref.read(orderHistoryViewModelProvider.notifier).loadMore();
    }
  }

  /// Order History ki poori list (sirf search se filter hoti hai).
  List<PosOrder> _filtered(OrderHistoryState s) {
    final String q = _query.trim().toLowerCase();
    return s.orders.where((PosOrder o) {
      if (q.isEmpty) return true;
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final double gap = m ? 12 : 16;
    final OrderHistoryState state = ref.watch(orderHistoryViewModelProvider);
    final OrderHistoryViewModel vm =
    ref.read(orderHistoryViewModelProvider.notifier);
    final List<PosOrder> list = _filtered(state);

    // Filter ke baad list chhoti reh jaye to scroll nahi hoga, isliye khud aur laao.
    if (list.length < 6 &&
        state.hasMore &&
        !state.isLoading &&
        !state.isRefreshing &&
        !state.isLoadingMore &&
        state.loadMoreFailure == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) vm.loadMore();
      });
    }

    Widget body;
    if (state.isLoading && state.orders.isEmpty) {
      body = const _ListSkeleton();
    } else if (state.failure != null && state.orders.isEmpty) {
      body = AppErrorView(failure: state.failure!, onRetry: vm.reload);
    } else if (list.isEmpty && !state.hasMore) {
      body = _EmptyView(
        searching: _query.trim().isNotEmpty,
        onRefresh: () async {
          await vm.refresh();
        },
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await vm.refresh();
        },
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: gap),
          itemBuilder: (BuildContext context, int i) {
            if (i < list.length) return _OrderCard(order: list[i]);
            return _ListFooter(
              loading: state.isLoadingMore,
              failure: state.loadMoreFailure,
              onRetry: () => vm.loadMore(retry: true),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m ? 16 : 32),
          child: ResponsiveCenter(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: AppText.h2('Exchange')),
                  ],
                ),
                SizedBox(height: gap),
                PosField(
                  controller: _search,
                  hint: 'Search order number or customer',
                  icon: Icons.search_rounded,
                  onChanged: (String v) => setState(() => _query = v),
                  suffix: _query.isEmpty
                      ? null
                      : IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                SizedBox(height: gap),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PosOrder order;

  @override
  Widget build(BuildContext context) {
    final List<OrderLine> lines = order.items;
    final int more = lines.length > 2 ? lines.length - 2 : 0;
    final bool allReturned = lines.isNotEmpty &&
        lines.every((OrderLine l) => !l.canExchange);

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  order.orderNumber,
                  AppTextStyles.bodyBold,
                  m: 14,
                  t: 15,
                  maxLines: 1,
                ),
              ),
              AdaptiveText(
                FormatUtils.inr(order.total),
                AppTextStyles.bodyBold,
                m: 14,
                t: 15,
              ),
            ],
          ),
          const SizedBox(height: 2),
          AdaptiveText(
            '${order.customerName} • ${FormatUtils.dateTime(order.createdAt)}',
            AppTextStyles.caption,
            m: 11,
            t: 12,
            secondary: true,
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          for (final OrderLine l in lines.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: AdaptiveText(
                '• ${l.productName} × ${l.quantity}'
                    '${l.returnedQty > 0 ? '  (${l.returnedQty} returned)' : ''}',
                AppTextStyles.body,
                m: 12,
                t: 13,
                secondary: true,
                maxLines: 1,
              ),
            ),
          if (more > 0)
            AdaptiveText(
              '+$more more ${more == 1 ? 'item' : 'items'}',
              AppTextStyles.caption,
              m: 11,
              t: 12,
              secondary: true,
            ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  order.payments.isEmpty ? '' : 'Paid: ${order.paymentLabel}',
                  AppTextStyles.caption,
                  m: 11,
                  t: 12,
                  secondary: true,
                  maxLines: 1,
                ),
              ),
              if (order.canExchange)
                ExchangeButton(order: order)
              else if (allReturned)
                const _ReturnedPill(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Jis order ki saari items return / exchange ho chuki hon.
class _ReturnedPill extends StatelessWidget {
  const _ReturnedPill();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Returned',
        style: AppTextStyles.bodyBold.copyWith(
          fontSize: 12,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.loading,
    required this.failure,
    required this.onRetry,
  });

  final bool loading;
  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
      );
    }
    if (failure != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Could not load more. Retry'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    final double gap = context.isMobile ? 12 : 16;
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (_, _) => const ShimmerBone(
          width: double.infinity,
          height: 150,
          radius: 20,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.searching, required this.onRefresh});

  final bool searching;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final Color color = dark ? AppColors.primaryLight : AppColors.primary;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: context.palette.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          size: 40,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppText.h2(
                        searching ? 'No matching orders' : 'No orders yet',
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      AppText.body(
                        searching
                            ? 'Try a different order number or customer name.'
                            : 'Your POS orders will show up here. You can exchange items from any completed order.',
                        align: TextAlign.center,
                        secondary: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}