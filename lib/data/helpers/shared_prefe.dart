import 'package:shared_preferences/shared_preferences.dart';

class SharePrefsHelper {
  static const String accessTokenKey = "accessToken";
  static const String refreshTokenKey = "refreshToken";
  static const String isLoginKey = "isLogin";
  static const String userIdKey = "userId";
  static const String userEmailKey = "userEmail";
  static const String fcmTokenKey = "fcmDeviceToken";
  static const String isGuestKey = "isGuest";

  static bool get isGuest => getBool(isGuestKey);
  static Future<bool> setGuest(bool value) => setBool(isGuestKey, value);

  static SharedPreferences? _prefs;

  // Initialize SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save String
  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  // Get String
  static String getString(String key) {
    return _prefs?.getString(key) ?? "";
  }

  // Save Bool
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  // Get Bool
  static bool getBool(String key) {
    return _prefs?.getBool(key) ?? false;
  }

  // Remove Key
  static Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  // Clear all
  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }
}
