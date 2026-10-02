/// Local storage ke saare keys ek jagah, taaki typo na ho.
class StorageKeys {
  StorageKeys._();

  // Session (logout pe clear hota hai)
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user_json';
  static const String activeShiftId = 'active_shift_id';

  // Device preferences (logout pe clear NAHI hota)
  static const String rememberedPhone = 'remembered_phone';
  static const String themeMode = 'theme_mode';
  static const String printerAddress = 'printer_address';
}