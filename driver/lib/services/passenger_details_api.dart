// services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ApiService {
  static const String baseUrl = 'https://smiling-sparrow-proper.ngrok-free.app/api/v1';

  // Get headers with authentication token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await Auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get user details
  static Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['user'];
        }
      }
      throw Exception('Failed to fetch user details');
    } catch (e) {
      rethrow;
    }
  }

  // Mark as arrived
  static Future<void> markAsArrived(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/services/$requestId/arrived'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 ||
          json.decode(response.body)['success'] != true) {
        throw Exception(json.decode(response.body)['message'] ?? 'Failed to mark as arrived');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Start trip
  static Future<void> startTrip(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/services/$requestId/start'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 ||
          json.decode(response.body)['success'] != true) {
        throw Exception(json.decode(response.body)['message'] ?? 'Failed to start trip');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Complete ride
  static Future<void> completeRide(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/services/$requestId/complete'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 ||
          json.decode(response.body)['success'] != true) {
        throw Exception(json.decode(response.body)['message'] ?? 'Failed to complete ride');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Cancel ride (driver)
  static Future<void> cancelRide(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/services/$requestId/driver-cancel'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 ||
          json.decode(response.body)['success'] != true) {
        throw Exception(json.decode(response.body)['message'] ?? 'Failed to cancel ride');
      }
    } catch (e) {
      rethrow;
    }
  }
}