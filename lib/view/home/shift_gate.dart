import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/view/home/shift_card.dart';
import 'package:shopzo_pos/view/home/shift_close_report.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_loader.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'open_shift_card.dart';


/// Home ko iske andar lapet do:  `ShiftGate(child: MainShellScreen())`
///
/// Login ke baad (admin, manager, cashier sabke liye) dashboard ke upar,
/// jab tak shift open na ho, blur ke saath popup aata hai:
///  - shift check ho raha hai  -> "Checking your shift..."
///  - open shift nahi hai      -> Open Shift popup (opening cash)
///  - shift abhi close hui     -> Shift closed report
///  - check fail (net/server)  -> error + Retry / Logout
/// Shift open hote hi popup hat jata hai. App background se wapas aane par
/// shift server se dobara sync hota hai.
class ShiftGate extends ConsumerStatefulWidget {
  const ShiftGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShiftGate> createState() => _ShiftGateState();
}

class _ShiftGateState extends ConsumerState<ShiftGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Shift kisi aur device / website se band hui ho to yahan bhi pata chale.
    if (state == AppLifecycleState.resumed) {
      ref.read(shiftViewModelProvider.notifier).refreshActive(silent: true);
    }
  }

  Widget? _cardFor(ShiftState s) {
    // Close ke turant baad pehle report dikhao.
    if (s.closedShift != null) {
      return const ShiftClosedReport(key: ValueKey<String>('closed'));
    }
    switch (s.phase) {
      case ShiftPhase.checking:
        return const _CheckingCard(key: ValueKey<String>('checking'));
      case ShiftPhase.none:
        return const OpenShiftCard(key: ValueKey<String>('open'));
      case ShiftPhase.error:
        return _ErrorCard(
          key: const ValueKey<String>('error'),
          failure: s.failure,
        );
      case ShiftPhase.open:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShiftState s = ref.watch(shiftViewModelProvider);
    final Widget? card = _cardFor(s);

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: card == null
                ? const SizedBox.shrink(key: ValueKey<String>('no-overlay'))
                : _Backdrop(
              key: const ValueKey<String>('overlay'),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: card,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Blur + dim barrier (neeche ka dashboard tap nahi hota) aur card ko beech me rakhta hai.
class _Backdrop extends StatelessWidget {
  const _Backdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: const ModalBarrier(
              dismissible: false,
              color: AppColors.overlay,
            ),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              // Keyboard khulne par card upar khisak jaye.
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckingCard extends StatelessWidget {
  const _CheckingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShiftCardShell(
      maxWidth: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppLoader(size: 36, strokeWidth: 3.5),
          SizedBox(height: 16),
          AppText.bodyBold('Checking your shift…', align: TextAlign.center),
          SizedBox(height: 4),
          AppText.caption('Please wait a moment', align: TextAlign.center),
        ],
      ),
    );
  }
}

/// Shift check hi nahi ho paya: server ka message + Retry / Logout.
class _ErrorCard extends ConsumerWidget {
  const _ErrorCard({super.key, required this.failure});

  final Failure? failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String message =
        failure?.message ?? 'Could not check your shift. Please try again.';
    final int? code = failure?.statusCode;

    return ShiftCardShell(
      maxWidth: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Center(
            child: ShiftHeaderIcon(
              icon: Icons.cloud_off_rounded,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(height: 16),
          const AppText.h2('Could not check shift', align: TextAlign.center),
          const SizedBox(height: 6),
          AppText.body(message, align: TextAlign.center, secondary: true),
          if (code != null) ...<Widget>[
            const SizedBox(height: 8),
            AppText.caption('Error code $code', align: TextAlign.center),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Try again',
            leadingIcon: Icons.refresh_rounded,
            onPressed: () =>
                ref.read(shiftViewModelProvider.notifier).refreshActive(),
          ),
          const SizedBox(height: 6),
          AppButton(
            label: 'Logout',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.medium,
            onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}