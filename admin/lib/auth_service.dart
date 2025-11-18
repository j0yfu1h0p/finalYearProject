import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _baseUrl =
      'https://smiling-sparrow-proper.ngrok-free.app/api/admin/auth';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _storage.write(key: 'auth_token', value: data['token']);
        await _storage.write(key: 'user_id', value: data['user']['id']);
        await _storage.write(key: 'username', value: data['user']['username']);
        await _storage.write(key: 'user_role', value: data['user']['role']);
        await _storage.write(
          key: 'is_active',
          value: data['user']['active'].toString(),
        );

        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        throw data['message'] ?? 'Login failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final username = await _storage.read(key: 'username');
      final role = await _storage.read(key: 'user_role');
      final isActive = await _storage.read(key: 'is_active');

      if (token == null || username == null || role == null) {
        return null;
      }

      return {
        'token': token,
        'username': username,
        'role': role,
        'isActive': isActive == 'true',
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null && user['token'] != null;
  }

  Future<bool> isSuperAdmin() async {
    final user = await getCurrentUser();
    return user != null && user['role'] == 'superadmin';
  }

  Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    return user != null && user['role'] == 'admin';
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
}
