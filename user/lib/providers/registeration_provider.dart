import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _countryCode = "+92"; // Default
  String _flagEmoji = "🇵🇰";
  String get countryCode => _countryCode;
  String get flagEmoji => _flagEmoji;

  void setCountry(String code, String emoji) {
    _countryCode = code;
    _flagEmoji = emoji;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleanNumber.isNotEmpty && cleanNumber.length >= 7 && cleanNumber.length <= 15;
  }

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    _setLoading(true);
    try {
      final result = await _apiService.sendOtp(phoneNumber);
      return result;
    } on TimeoutException {
      return {'success': false, 'message': 'Request timeout. Please try again.'};
    } on SocketException {
      return {'success': false, 'message': 'Network error. Check your internet connection.'};
    } on FormatException {
      return {'success': false, 'message': 'Invalid response from server. Try again.'};
    } on HttpException {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    } finally {
      _setLoading(false);
    }
  }
}
