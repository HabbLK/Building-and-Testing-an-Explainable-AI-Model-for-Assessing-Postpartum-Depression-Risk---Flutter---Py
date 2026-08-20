import 'package:shared_preferences/shared_preferences.dart';

/// On-device state only: onboarding flag, the cached session for the
/// signed-in user (token/name/email issued by the Flask+MongoDB backend),
/// and the dark-mode preference. All account and check-in data itself now
/// lives server-side in MongoDB — see api/db.py.
class LocalStore {
  static const _kOnboarding = 'seen_onboarding';
  static const _kToken = 'session_token';
  static const _kName = 'session_name';
  static const _kEmail = 'session_email';
  static const _kDarkMode = 'dark_mode';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboarding) ?? false;
  }

  static Future<void> setSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }

  static Future<void> saveSession(String token, String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kName, name);
    await prefs.setString(_kEmail, email);
  }

  static Future<void> updateCachedName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken) != null;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<Map<String, String>?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null) return null;
    return {
      'name': prefs.getString(_kName) ?? '',
      'email': prefs.getString(_kEmail) ?? '',
    };
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDarkMode) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, value);
  }
}
