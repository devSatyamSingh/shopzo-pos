typedef AppValidator = String? Function(String? value);
class Validators {
  Validators._();

  static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );
  static final RegExp _nameRegex = RegExp(r"^[A-Za-z][A-Za-z .'\-]*$");

  static AppValidator required([String fieldName = 'This field']) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required';
      }
      return null;
    };
  }

  static AppValidator minLength(int length, [String fieldName = 'This field']) {
    return (String? value) {
      if (value == null || value.trim().length < length) {
        return '$fieldName must be at least $length characters';
      }
      return null;
    };
  }

  static AppValidator maxLength(int length, [String fieldName = 'This field']) {
    return (String? value) {
      if (value != null && value.trim().length > length) {
        return '$fieldName must be at most $length characters';
      }
      return null;
    };
  }

  static AppValidator optional(AppValidator validator) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) return null;
      return validator(value);
    };
  }

  static AppValidator compose(List<AppValidator> validators) {
    return (String? value) {
      for (final AppValidator validator in validators) {
        final String? error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }


  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final String cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!_phoneRegex.hasMatch(cleaned)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    final String v = value.trim();
    if (v.length < 2) return 'Name is too short';
    if (!_nameRegex.hasMatch(v)) return 'Name can contain only letters';
    return null;
  }


  /// Login ke liye: sirf required check. Login pe strength rules mat lagao.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter';
    if (!RegExp(r'\d').hasMatch(value)) return 'Add a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Add a special character';
    }
    return null;
  }

  static AppValidator confirmPassword(String Function() original) {
    return (String? value) {
      if (value == null || value.isEmpty) return 'Confirm your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }

  // ── Numbers / POS ────────────────────────────────────────────────────────

  /// Amount (opening cash, closing cash, discount, received amount).
  static AppValidator amount({
    String fieldName = 'Amount',
    bool allowZero = false,
    double? max,
  }) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required';
      }
      final double? parsed = double.tryParse(value.replaceAll(',', '').trim());
      if (parsed == null) return 'Enter a valid $fieldName';
      if (parsed < 0 || (!allowZero && parsed == 0)) {
        return '$fieldName must be greater than 0';
      }
      if (max != null && parsed > max) {
        return '$fieldName cannot be more than $max';
      }
      return null;
    };
  }

  static String? pincode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Pincode is required';
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(value.trim())) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }
}