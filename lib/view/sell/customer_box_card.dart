import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/customer_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/view/sell/pos_card.dart';
import 'package:shopzo_pos/viewmodel/billing_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/customer_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';

/// Cart panel ka "Customer" card: phone se search, select, ya naya customer.
/// Customer na ho to walk-in sale.
class CustomerBox extends ConsumerStatefulWidget {
  const CustomerBox({super.key});

  @override
  ConsumerState<CustomerBox> createState() => _CustomerBoxState();
}

class _CustomerBoxState extends ConsumerState<CustomerBox> {
  final TextEditingController _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _select(CustomerModel c) {
    ref.read(billingViewModelProvider.notifier).setCustomer(c);
    _phone.clear();
    ref.read(customerSearchProvider.notifier).clear();
    AppUtils.hideKeyboard();
  }

  Future<void> _newCustomer() async {
    final CustomerModel? created = await showNewCustomerSheet(
      context,
      initialPhone: _phone.text.trim(),
    );
    if (created != null) _select(created);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final CustomerModel? selected =
    ref.watch(billingViewModelProvider.select((BillingState s) => s.customer));
    final CustomerSearchState search = ref.watch(customerSearchProvider);

    return PosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              AdaptiveText('Customer', AppTextStyles.title, m: 14, t: 16),
              const Spacer(),
              if (selected == null)
                AdaptiveText('Walk-in', AppTextStyles.caption,
                    m: 11, t: 12, secondary: true),
            ],
          ),
          SizedBox(height: m ? 10 : 12),
          if (selected != null)
            _SelectedCustomer(
              customer: selected,
              onRemove: () =>
                  ref.read(billingViewModelProvider.notifier).clearCustomer(),
            )
          else ...<Widget>[
            PosField(
              controller: _phone,
              hint: 'Search by mobile number',
              icon: Icons.search_rounded,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (String v) {
                ref.read(customerSearchProvider.notifier).onChanged(v);
                setState(() {});
              },
              suffix: _phone.text.isEmpty
                  ? null
                  : IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: palette.textSecondary),
                onPressed: () {
                  _phone.clear();
                  ref.read(customerSearchProvider.notifier).clear();
                  setState(() {});
                },
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _Results(search: search, onSelect: _select),
            ),
            SizedBox(height: m ? 6 : 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _newCustomer,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  'New customer',
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: m ? 12 : 13,
                    color: palette.isDark
                        ? AppColors.primaryLight
                        : AppColors.primary,
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

class _Results extends StatelessWidget {
  const _Results({required this.search, required this.onSelect});

  final CustomerSearchState search;
  final ValueChanged<CustomerModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!search.isSearching) return const SizedBox(width: double.infinity);

    if (search.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                strokeCap: StrokeCap.round,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            AdaptiveText('Searching…', AppTextStyles.body,
                m: 12, t: 13, secondary: true),
          ],
        ),
      );
    }

    if (search.failure != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: AdaptiveText(search.failure!.message, AppTextStyles.body,
            m: 12, t: 13, color: AppColors.coral),
      );
    }

    if (search.results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: AdaptiveText('No customer found for "${search.query}".',
            AppTextStyles.body, m: 12, t: 13, secondary: true),
      );
    }

    return Column(
      children: <Widget>[
        const SizedBox(height: 6),
        for (final CustomerModel c in search.results.take(5))
          _CustomerTile(customer: c, onTap: () => onSelect(c)),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});

  final CustomerModel customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: <Widget>[
            _Avatar(text: customer.initials, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AdaptiveText(customer.name, AppTextStyles.bodyBold,
                      m: 13, t: 14, maxLines: 1),
                  AdaptiveText(customer.phone, AppTextStyles.caption,
                      m: 11, t: 12, secondary: true),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded,
                size: 20, color: context.palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SelectedCustomer extends StatelessWidget {
  const _SelectedCustomer({required this.customer, required this.onRemove});

  final CustomerModel customer;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: palette.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          _Avatar(text: customer.initials, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveText(customer.name, AppTextStyles.bodyBold,
                    m: 13, t: 15, maxLines: 1),
                AdaptiveText(customer.phone, AppTextStyles.caption,
                    m: 11, t: 12, secondary: true),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove customer',
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyBold.copyWith(
          color: Colors.white,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// New customer (quick create)
// ═══════════════════════════════════════════════════════════════════════════

/// Naya customer banata hai. Success par [CustomerModel] wapas deta hai.
Future<CustomerModel?> showNewCustomerSheet(
    BuildContext context, {
      String initialPhone = '',
    }) {
  return showModalBottomSheet<CustomerModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (BuildContext context) =>
        _NewCustomerSheet(initialPhone: initialPhone),
  );
}

class _NewCustomerSheet extends ConsumerStatefulWidget {
  const _NewCustomerSheet({required this.initialPhone});

  final String initialPhone;

  @override
  ConsumerState<_NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends ConsumerState<_NewCustomerSheet> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _phone =
  TextEditingController(text: widget.initialPhone);

  bool _busy = false;
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    AppUtils.hideKeyboard();
    final String name = _name.text.trim();
    final String phone = _phone.text.trim();

    setState(() {
      _nameError = name.length < 2 ? 'Enter the customer name' : null;
      _phoneError = phone.length != 10 ? 'Enter a 10 digit mobile number' : null;
    });
    if (_nameError != null || _phoneError != null) return;

    setState(() => _busy = true);
    final ApiResult<CustomerModel> result = await ref
        .read(customerSearchProvider.notifier)
        .create(name: name, phone: phone);
    if (!mounted) return;
    setState(() => _busy = false);

    // Server ka message ("Customer created") + status code, ya error.
    AppUtils.showResult(result, successFallback: 'Customer created');

    final CustomerModel? created = result.dataOrNull;
    if (created != null) {
      Navigator.of(context).pop(created);
      return;
    }
    final Failure? f = result.failureOrNull;
    if (f != null) {
      setState(() {
        _nameError = f.fieldError('name');
        _phoneError = f.fieldError('phone');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AdaptiveText('New customer', AppTextStyles.h2, m: 18, t: 20),
                const SizedBox(height: 2),
                AdaptiveText('Only name and mobile number are needed.',
                    AppTextStyles.body, m: 12, t: 13, secondary: true),
                const SizedBox(height: 16),
                PosField(
                  controller: _name,
                  label: 'Customer name',
                  icon: Icons.person_outline_rounded,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  errorText: _nameError,
                ),
                const SizedBox(height: 12),
                PosField(
                  controller: _phone,
                  label: 'Mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  errorText: _phoneError,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Save customer',
                  leadingIcon: Icons.check_rounded,
                  isLoading: _busy,
                  onPressed: _save,
                ),
                const SizedBox(height: 4),
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.medium,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}