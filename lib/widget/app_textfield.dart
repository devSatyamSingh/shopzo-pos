import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/validators.dart';
import 'app_colors.dart';
import 'app_text.dart';
import 'app_textstyle.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.isPassword = false,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.errorText,
    this.helperText,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode,
    this.autofillHints,
  });

  /// Indian mobile number: 10 digits, +91 prefix, digits-only keyboard.
  factory AppTextField.phone({
    Key? key,
    TextEditingController? controller,
    FocusNode? focusNode,
    String label = 'Mobile number',
    String hint = 'Enter 10-digit mobile number',
    AppValidator? validator,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? errorText,
    bool enabled = true,
    bool autofocus = false,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      label: label,
      hint: hint,
      validator: validator ?? Validators.phone,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      maxLength: 10,
      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
      prefixIcon: Icons.phone_outlined,
      prefix: const _CountryCode(),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      errorText: errorText,
      enabled: enabled,
      autofocus: autofocus,
      autofillHints: const <String>[AutofillHints.telephoneNumberNational],
    );
  }

  /// Password with show/hide eye. Login ke liye default validator sirf "required" hai.
  factory AppTextField.password({
    Key? key,
    TextEditingController? controller,
    FocusNode? focusNode,
    String label = 'Password',
    String hint = 'Enter your password',
    AppValidator? validator,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? errorText,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      label: label,
      hint: hint,
      validator: validator ?? Validators.password,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      obscureText: true,
      isPassword: true,
      prefixIcon: Icons.lock_outline_rounded,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      errorText: errorText,
      enabled: enabled,
      autofillHints: const <String>[AutofillHints.password],
    );
  }

  /// Product search bar (New Sale screen). Label nahi hota.
  factory AppTextField.search({
    Key? key,
    TextEditingController? controller,
    FocusNode? focusNode,
    String hint = 'Search product, SKU or barcode',
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onScanTap,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      textInputAction: TextInputAction.search,
      prefixIcon: Icons.search_rounded,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      suffix: onScanTap == null
          ? null
          : IconButton(
        onPressed: onScanTap,
        tooltip: 'Scan barcode',
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
        color: AppColors.primary,
      ),
    );
  }

  /// Money input (opening cash, closing cash, discount). Max 2 decimals.
  factory AppTextField.amount({
    Key? key,
    TextEditingController? controller,
    FocusNode? focusNode,
    String label = 'Amount',
    String hint = '0.00',
    AppValidator? validator,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? errorText,
    bool autofocus = false,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      label: label,
      hint: hint,
      validator: validator ?? Validators.amount(fieldName: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}\.?\d{0,2}')),
      ],
      prefix: const _RupeeSign(),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      errorText: errorText,
      autofocus: autofocus,
    );
  }

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final AppValidator? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  /// true = eye toggle dikhega.
  final bool isPassword;
  final IconData? prefixIcon;

  /// Icon ke baad ka custom widget (jaise +91, ₹).
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;

  /// Server / external error. Set ho to validator ke upar dikhta hai.
  final String? errorText;
  final String? helperText;
  final TextCapitalization textCapitalization;

  /// Default: user interact kare tab validate (onUserInteraction).
  final AutovalidateMode? autovalidateMode;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _attachFocusNode();
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _hasFocus = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChange);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
  }

  void _onFocusChange() {
    if (_hasFocus != _focusNode.hasFocus && mounted) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    super.dispose();
  }

  Widget? _buildPrefix(Color iconColor) {
    if (widget.prefixIcon == null && widget.prefix == null) return null;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.prefixIcon != null)
            Icon(widget.prefixIcon, size: 20, color: iconColor),
          if (widget.prefixIcon != null && widget.prefix != null)
            const SizedBox(width: 10),
          if (widget.prefix != null) widget.prefix!,
        ],
      ),
    );
  }

  Widget? _buildSuffix(AppPalette palette) {
    if (widget.isPassword) {
      return IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: palette.textHint,
        ),
      );
    }
    return widget.suffix;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final Color iconColor = hasError
        ? AppColors.coral
        : (_hasFocus ? AppColors.primary : palette.textHint);

    final Widget field = TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscure,
      obscuringCharacter: '•',
      maxLength: widget.maxLength,
      maxLines: _obscure ? 1 : widget.maxLines,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      autovalidateMode:
      widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
      autofillHints: widget.autofillHints,
      cursorColor: AppColors.primary,
      style: AppTextStyles.bodyLarge.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: hasError ? widget.errorText : null,
        counterText: '',
        prefixIcon: _buildPrefix(iconColor),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: _buildSuffix(palette),
      ),
    );

    if (widget.label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppText.label(widget.label!, secondary: false),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '+91',
          style: AppTextStyles.bodyBold.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 20, color: palette.border),
      ],
    );
  }
}

class _RupeeSign extends StatelessWidget {
  const _RupeeSign();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Text(
      '₹',
      style: AppTextStyles.title.copyWith(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}