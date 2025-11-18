  import 'package:jwt_decoder/jwt_decoder.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  class Auth {
    static const String _tokenKey = 'jwt_token';
    static const String _refreshTokenKey = 'refresh_token';

    static Future<void> setToken(String token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }

    static Future<void> removeToken() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('driverStatus');
      await prefs.remove('mechanicStatus');
      await prefs.remove(_tokenKey);
    }

    static Future<void> saveToken(String token) async {
      await setToken(token);
    }

    static Future<void> saveTokens(String token, String refreshToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    static Future<String?> getToken() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }

    static Future<String?> getRefreshToken() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    }

    static Future<bool> hasToken() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_tokenKey);
    }

    static Future<void> clearTokens() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
    }

    static Future<bool> isTokenValid() async {
      final token = await getToken();
      if (token == null) return false;
      try {
        return !JwtDecoder.isExpired(token);
      } catch (e) {
        return false;
      }
    }
  }