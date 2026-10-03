import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/model/held_order_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/sell/pos_card.dart';
import 'package:shopzo_pos/viewmodel/billing_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/held_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

/// Held (parked) sales. Resume dabane par cart bhar jaata hai aur [onResumed]
/// se Sell tab khul jaata hai.
class HeldScreen extends ConsumerWidget {
  const HeldScreen({super.key, required this.onResumed});

  final VoidCallback onResumed;

  Future<bool> _confirm(
      BuildContext context, {
        required String title,
        required String message,
        required String action,
        bool danger = false,
      }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: AppTextStyles.h2),
        content: Text(message, style: AppTextStyles.body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              action,
              style: TextStyle(color: danger ? AppColors.coral : AppColors.primary),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _resume(BuildContext context, WidgetRef ref, HeldOrder h) async {
    // Cart me pehle se kuch ho to replace hoga, pehle pooch lo.
    if (ref.read(billingViewModelProvider).cart.isNotEmpty) {
      final bool ok = await _confirm(
        context,
        title: 'Replace current cart?',
        message: 'The items in your current sale will be replaced by this held sale.',
        action: 'Replace',
      );
      if (!ok || !context.mounted) return;
    }

    final ResumeOutcome out =
    await ref.read(heldViewModelProvider.notifier).resume(h);
    if (!context.mounted) return;

    if (out.ok && out.warnings.isNotEmpty) {
      AppUtils.showWarning('Resumed. Skipped / adjusted: ${out.warnings.join(', ')}');
    } else {
      AppUtils.showResult(out.result, successFallback: 'Order resumed');
    }
    if (out.ok) onResumed();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, HeldOrder h) async {
    final bool ok = await _confirm(
      context,
      title: 'Discard held sale?',
      message: 'This held sale will be cancelled and cannot be resumed.',
      action: 'Discard',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final result = await ref.read(heldViewModelProvider.notifier).cancel(h);
    AppUtils.showResult(result, successFallback: 'Held order cancelled');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final HeldState state = ref.watch(heldViewModelProvider);
    final HeldViewModel vm = ref.read(heldViewModelProvider.notifier);
    final bool m = context.isMobile;

    // Product naam dikhane ke liye (jo products load ho chuke hain).
    final Map<String, String> names = <String, String>{
      for (final p in ref.watch(posProductsProvider.select((s) => s.items)))
        p.id: p.name,
    };

    Widget body;
    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.failure != null && state.items.isEmpty) {
      body = AppErrorView(failure: state.failure!, onRetry: () => vm.load());
    } else if (state.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => vm.load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: m ? 90 : 140),
            Icon(Icons.pause_circle_outline_rounded, size: 52, color: palette.textHint),
            const SizedBox(height: 12),
            Center(child: AdaptiveText('No held sales', AppTextStyles.title, m: 16)),
            const SizedBox(height: 4),
            Center(
              child: AdaptiveText(
                'Use "Hold sale" on the payment screen to park a sale.',
                AppTextStyles.body,
                m: 12,
                secondary: true,
                align: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => vm.load(refresh: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: state.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int i) {
            final HeldOrder h = state.items[i];
            return _HeldCard(
              order: h,
              summary: h.items
                  .map((HeldItem it) => '${names[it.productId] ?? 'Item'} × ${it.quantity}')
                  .join(', '),
              busy: state.busyIds.contains(h.id),
              onResume: () => _resume(context, ref, h),
              onCancel: () => _cancel(context, ref, h),
            );
          },
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ResponsiveCenter(
        maxWidth: 760,
        alignment: Alignment.topCenter,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: <Widget>[
                  AdaptiveText('Held sales', AppTextStyles.h2, m: 18, t: 20),
                  const SizedBox(width: 8),
                  if (state.items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${state.items.length}',
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 12,
                          color: palette.isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => vm.load(refresh: true),
                    icon: Icon(Icons.refresh_rounded, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _HeldCard extends StatelessWidget {
  const _HeldCard({
    required this.order,
    required this.summary,
    required this.busy,
    required this.onResume,
    required this.onCancel,
  });

  final HeldOrder order;
  final String summary;
  final bool busy;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final String who = order.customer?.name ?? 'Walk-in customer';

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: m ? 40 : 46,
                height: m ? 40 : 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                child: order.customer != null
                    ? Text(
                  order.customer!.initials,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: const Color(0xFFE08A00),
                  ),
                )
                    : const Icon(Icons.pause_rounded, color: Color(0xFFE08A00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdaptiveText(who, AppTextStyles.bodyBold, m: 14, t: 15, maxLines: 1),
                    AdaptiveText(
                      'Held ${FormatUtils.since(order.createdAt)}',
                      AppTextStyles.caption,
                      m: 11,
                      t: 12,
                      secondary: true,
                    ),
                  ],
                ),
              ),
              AdaptiveText(
                '${order.totalQty} ${order.totalQty == 1 ? 'item' : 'items'}',
                AppTextStyles.bodyBold,
                m: 12,
                t: 13,
              ),
            ],
          ),
          if (summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            AdaptiveText(summary, AppTextStyles.body, m: 12, t: 13, secondary: true, maxLines: 2),
          ],
          if (order.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.sticky_note_2_outlined, size: 16, color: palette.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: AdaptiveText(order.note, AppTextStyles.caption,
                      m: 11, t: 12, secondary: true, maxLines: 2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Resume',
                  leadingIcon: Icons.play_arrow_rounded,
                  size: AppButtonSize.small,
                  isLoading: busy,
                  onPressed: busy ? null : onResume,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Discard',
                onPressed: busy ? null : onCancel,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hold note dialog (payment sheet se use hota hai)
// ═══════════════════════════════════════════════════════════════════════════

/// Optional note poochta hai. Cancel par null, "Hold" par note (khali bhi ho sakta hai).
Future<String?> showHoldNoteDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => const _HoldNoteDialog(),
  );
}

class _HoldNoteDialog extends StatefulWidget {
  const _HoldNoteDialog();

  @override
  State<_HoldNoteDialog> createState() => _HoldNoteDialogState();
}

class _HoldNoteDialogState extends State<_HoldNoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Hold this sale?', style: AppTextStyles.h2),
      content: PosField(
        controller: _note,
        hint: 'Note (optional), e.g. back in 5 min',
        icon: Icons.sticky_note_2_outlined,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: const Text('Hold', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}