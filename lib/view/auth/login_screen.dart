import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/user_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';
import 'package:shopzo_pos/viewmodel/auth_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
import 'package:shopzo_pos/widget/app_text.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../core/routes/route_name.dart';
import '../../utils/responsive.dart';
import '../../widget/app_textfield.dart';

enum _BadgeKind { idle, filled, error, loading }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _remember = false;

  // Ye dono build() mein authViewModel se sync hote hain.
  bool _isLoading = false;
  Failure? _failure;

  String? get _error => _failure?.message;

  bool get _filled =>
      _phone.text.trim().length == 10 && _password.text.isNotEmpty;

  _BadgeKind get _kind => _isLoading
      ? _BadgeKind.loading
      : _error != null
      ? _BadgeKind.error
      : _filled
      ? _BadgeKind.filled
      : _BadgeKind.idle;

  String get _subtitle {
    if (_isLoading) return 'Verifying your credentials…';
    if (_error != null) return 'Check your details and try again';
    return 'Sign in to start your shift';
  }

  /// Error ke type ke hisaab se chhota hint.
  String? get _errorHint {
    final Failure? f = _failure;
    if (f == null) return null;
    switch (f.type) {
      case FailureType.noInternet:
      case FailureType.timeout:
        return 'Check your connection and try again.';
      case FailureType.server:
        return 'Please try again in a moment.';
      case FailureType.unauthorized:
      case FailureType.badRequest:
      case FailureType.validation:
        return 'Check your credentials and try again.';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _prefillRememberedPhone();
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _shake.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// "Remember me" se pichli baar ka number wapas bhar do.
  Future<void> _prefillRememberedPhone() async {
    final String? phone =
    await ref.read(authViewModelProvider.notifier).rememberedPhone();
    if (!mounted || phone == null || _phone.text.isNotEmpty) return;
    setState(() {
      _phone.text = phone;
      _remember = true;
    });
  }

  void _onChanged() {
    // Badge state (filled / idle) refresh + purana error hatao.
    ref.read(authViewModelProvider.notifier).clearError();
    setState(() {});
  }

  Future<void> _login() async {
    AppUtils.hideKeyboard();
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    final ApiResult<UserModel> result =
    await ref.read(authViewModelProvider.notifier).login(
      phone: _phone.text,
      password: _password.text,
      rememberMe: _remember,
    );

    // Server ka exact message + status code. AppUtils global hai, isliye
    // screen hat bhi jaye (redirect ke baad) tab bhi bubble dikhta hai.
    AppUtils.showResult(result, successFallback: 'Login successful');

    if (!mounted) return;
    if (result.isSuccess) context.go(AppRoutes.home);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authViewModelProvider);
    _isLoading = auth.isLoading;
    _failure = auth.failure;

    // Naya error aaye to form hilao + vibrate.
    ref.listen<AuthState>(authViewModelProvider,
            (AuthState? previous, AuthState next) {
          if (next.failure != null && next.failure != previous?.failure) {
            _shake.forward(from: 0);
            HapticFeedback.mediumImpact();
          }
        });

    final AppPalette palette = context.palette;
    // Tablet landscape = split screen. Baaki sab = hero + sheet.
    final bool wide = context.isTablet && context.isLandscape;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: wide && !palette.isDark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.background,
        body: wide
            ? _buildWide(palette)
            : LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) =>
              _buildMobile(palette, box),
        ),
      ),
    );
  }

  /// Phone + tablet portrait.
  Widget _buildMobile(AppPalette palette, BoxConstraints box) {
    final EdgeInsets inset = MediaQuery.paddingOf(context);
    final double heroHeight =
    (box.maxHeight * 0.40).clamp(270.0, 400.0).toDouble();

    return Stack(
      children: <Widget>[
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight + AppRadius.sheet,
          child: _HeroBackground(kind: _kind),
        ),
        SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: <Widget>[
              // Hero
              SizedBox(
                height: heroHeight,
                child: ResponsiveCenter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, inset.top + 12, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _PillChip(label: 'Shopzo POS'),
                        Expanded(
                          child: Center(
                            child: _HeroBadge(
                              kind: _kind,
                              size: heroHeight < 300 ? 64 : 88,
                            ),
                          ),
                        ),
                        const AppText.display('Welcome back',
                            color: Colors.white),
                        const SizedBox(height: 4),
                        AppText(
                          _subtitle,
                          type: AppTextType.bodyLarge,
                          color: AppColors.darkTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Form sheet
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: math.max(0, box.maxHeight - heroHeight),
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: AppRadius.sheetTop,
                ),
                padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + inset.bottom),
                child: ResponsiveCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildForm(palette),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWide(AppPalette palette) {
    return Row(
      children: <Widget>[
        Expanded(child: _BrandPanel(kind: _kind)),
        Expanded(
          child: ColoredBox(
            color: palette.background,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CustomPaint(painter: _DotGridPainter(color: palette.border)),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius:
                            BorderRadius.circular(AppRadius.sheet),
                            border: Border.all(color: palette.border),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: palette.shadow,
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: palette.primarySoft,
                                  borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                                ),
                                child: AppText.label(
                                  'TERMINAL LOGIN',
                                  color: palette.isDark
                                      ? AppColors.primaryLight
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const AppText.display('Welcome back'),
                              const SizedBox(height: 4),
                              AppText.body(_subtitle, secondary: true),
                              const SizedBox(height: 24),
                              _buildForm(palette),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AppPalette palette) {
    // Server ne field-wise error bheja ho (jaise phone) to wahi, warna sirf red border.
    final String? phoneError =
        _failure?.fieldError('phone') ?? (_error != null ? ' ' : null);

    return AnimatedBuilder(
      animation: _shake,
      builder: (BuildContext context, Widget? child) {
        final double t = _shake.value;
        final double dx = math.sin(t * math.pi * 6) * (1 - t) * 8;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: _error != null
                  ? Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ErrorBanner(
                  message: _error!,
                  hint: _errorHint,
                  statusCode: _failure?.statusCode,
                ),
              )
                  : const SizedBox(width: double.infinity),
            ),
            AppTextField.phone(
              controller: _phone,
              label: 'MOBILE NUMBER',
              enabled: !_isLoading,
              errorText: phoneError,
              onChanged: (_) => _onChanged(),
            ),
            const SizedBox(height: 16),
            AppTextField.password(
              controller: _password,
              label: 'PIN / PASSWORD',
              hint: 'Enter your PIN or password',
              enabled: !_isLoading,
              errorText: _error != null ? ' ' : null, // sirf red border
              onChanged: (_) => _onChanged(),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isLoading
                      ? null
                      : () => setState(() => _remember = !_remember),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _remember,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                            onChanged: _isLoading
                                ? null
                                : (bool? v) =>
                                setState(() => _remember = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const AppText.body('Remember me', secondary: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Sign in',
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _login,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'Need access? ',
                      style: AppTextStyles.caption
                          .copyWith(color: palette.textSecondary),
                    ),
                    TextSpan(
                      text: 'Contact your admin',
                      style: AppTextStyles.caption.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _glowFor(_BadgeKind kind) {
  switch (kind) {
    case _BadgeKind.error:
      return AppColors.coral;
    case _BadgeKind.filled:
      return AppColors.mint;
    case _BadgeKind.idle:
    case _BadgeKind.loading:
      return AppColors.primary;
  }
}

/// Dark gradient + glow. Error pe glow coral ho jaata hai.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.kind});

  final _BadgeKind kind;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _glowFor(kind)),
      duration: const Duration(milliseconds: 500),
      builder: (BuildContext context, Color? glow, Widget? _) {
        final Color g = glow ?? AppColors.primary;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF2A1F6B), AppColors.ink],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.9,
                  colors: <Color>[
                    g.withValues(alpha: 0.45),
                    g.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const <double>[0, 0.5, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1, 0.2),
                  radius: 0.7,
                  colors: <Color>[
                    AppColors.mint.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: Colors.white,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass badge: idle (bag + receipt), filled (check), error (cross), loading (spinner).
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.kind, required this.size});

  final _BadgeKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool loading = kind == _BadgeKind.loading;
    final double cornerSize = size * 0.33;

    // Corner chhota badge: rang aur icon state ke hisaab se.
    Color cornerBg = Colors.white;
    Color cornerFg = AppColors.primary;
    IconData cornerIcon = Icons.receipt_long_rounded;
    if (kind == _BadgeKind.filled) {
      cornerBg = AppColors.mint;
      cornerFg = AppColors.ink;
      cornerIcon = Icons.check_rounded;
    } else if (kind == _BadgeKind.error) {
      cornerBg = AppColors.coral;
      cornerFg = Colors.white;
      cornerIcon = Icons.close_rounded;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.3),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _glowFor(kind).withValues(alpha: 0.40),
                blurRadius: size * 0.55,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
              width: size * 0.38,
              height: size * 0.38,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: Colors.white,
              ),
            )
                : Icon(
              kind == _BadgeKind.error
                  ? Icons.error_outline_rounded
                  : Icons.shopping_bag_outlined,
              size: size * 0.42,
              color: Colors.white,
            ),
          ),
        ),
        if (!loading)
          Positioned(
            right: -size * 0.12,
            bottom: -size * 0.12,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: cornerSize,
              height: cornerSize,
              decoration: BoxDecoration(
                color: cornerBg,
                borderRadius: BorderRadius.circular(cornerSize * 0.32),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: cornerBg.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(cornerIcon, size: cornerSize * 0.58, color: cornerFg),
            ),
          ),
      ],
    );
  }
}

/// Server ka exact message + (optional) hint + status code.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    this.hint,
    this.statusCode,
  });

  final String message;
  final String? hint;
  final int? statusCode;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.palette.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.coral.withAlpha(36) : AppColors.coralSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.coral.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              color: AppColors.coral, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppText.bodyBold(message, color: AppColors.coral),
                if (hint != null) ...<Widget>[
                  const SizedBox(height: 2),
                  AppText.caption(hint!, secondary: true),
                ],
                if (statusCode != null) ...<Widget>[
                  const SizedBox(height: 2),
                  AppText.caption('Error code $statusCode', secondary: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.kind});

  final _BadgeKind kind;

  Widget _stat(String label, String value, {Color color = Colors.white}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.darkTextHint,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.bodyBold.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _note(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.darkTextSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.darkTextSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _HeroBackground(kind: kind),
        SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // Logo + name
                          Row(
                            children: <Widget>[
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      Color(0xFF2B2C4A),
                                      Color(0xFF12142A),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.4,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Text('P',
                                        style: AppTextStyles.h1
                                            .copyWith(color: Colors.white)),
                                    const Positioned(
                                      right: 9,
                                      bottom: 8,
                                      child: Icon(Icons.bolt_rounded,
                                          size: 16, color: AppColors.mint),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('Pulse POS',
                                      style: AppTextStyles.h2
                                          .copyWith(color: Colors.white)),
                                  Text(
                                    'ENTERPRISE TERMINAL',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.mint,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Decorative preview card (real data nahi)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.darkSurface
                                    .withValues(alpha: 0.85),
                                borderRadius:
                                BorderRadius.circular(AppRadius.xl),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      for (final Color c in const <Color>[
                                        AppColors.coral,
                                        AppColors.amber,
                                        AppColors.mint,
                                      ]) ...<Widget>[
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      const SizedBox(width: 4),
                                      Text(
                                        'PULSE-SYS://ACTIVE',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.darkTextHint,
                                          fontSize: 10,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '₹1,24,500.50',
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: AppColors.mint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: <Widget>[
                                      _stat('ORDERS', '142'),
                                      const SizedBox(width: 8),
                                      _stat('UPI RATE', '68%',
                                          color: AppColors.sky),
                                      const SizedBox(width: 8),
                                      _stat('SPEED', '1.2s'),
                                      const SizedBox(width: 8),
                                      _stat('SHIFT', '#2',
                                          color: AppColors.primaryLight),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Tagline
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Bill faster. Grow smarter.',
                                style: AppTextStyles.display.copyWith(
                                  color: Colors.white,
                                  fontSize: 32,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints:
                                const BoxConstraints(maxWidth: 400),
                                child: Text(
                                  'Fast billing, automated reconciliation and '
                                      'seamless multi-cashier shift management.',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkTextSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 20,
                                runSpacing: 8,
                                children: <Widget>[
                                  _note(Icons.lock_outline_rounded,
                                      'Secure sign-in'),
                                  _note(Icons.bolt_rounded,
                                      'Realtime billing'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double gap = 24;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final List<Offset> points = <Offset>[];
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}