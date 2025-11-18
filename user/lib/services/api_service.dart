import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../utils/error_handler.dart';

class ApiService {
  static const String baseUrl = 'https://smiling-sparrow-proper.ngrok-free.app';

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    final url = Uri.parse('$baseUrl/api/user/auth/send-otp');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final Map<String, String> body = {'phoneNumber': phoneNumber};

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.body.isEmpty) {
        throw FormatException('Empty response from server');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': ErrorHandler.sanitizeApiResponse(responseData, 'Failed to send verification code. Please try again.'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  Future<http.Response> getMechanicServiceRequests() async {
    final token = await Auth.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/mechanic/requests/user/requests/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return response;
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final url = Uri.parse('$baseUrl/api/user/auth/verify-otp');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final Map<String, String> body = {'phoneNumber': phoneNumber, 'otp': otp};

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.body.isEmpty) {
        throw FormatException('Empty response from server');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = responseData['token'];
        if (token == null || token.toString().isEmpty) {
          return {
            'success': false,
            'message': 'Authentication failed. Please try again.',
          };
        }

        return {
          'success': true,
          'token': token.toString(),
          'requiresFullName': responseData['requiresFullName'] == true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': ErrorHandler.sanitizeApiResponse(responseData, 'Invalid verification code. Please try again.'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> submitFullName(
      String phoneNumber,
      String fullName,
      ) async {
    final url = Uri.parse('$baseUrl/api/user/auth/submit-name');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final Map<String, String> body = {
      'phoneNumber': phoneNumber,
      'fullName': fullName,
    };

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.body.isEmpty) {
        throw FormatException('Empty response from server');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': ErrorHandler.sanitizeApiResponse(responseData, 'Failed to save your name. Please try again.'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  Future<http.Response> makeAuthenticatedRequest(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final token = await Auth.getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(body ?? {}),
    );
    return response;
  }

  Future<http.Response> getRecentBookingsUser() async {
    String url = "$baseUrl/api/history";
    final token = await Auth.getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(Uri.parse(url), headers: headers);
    return response;
  }

  Future<Map<String, dynamic>> createServiceRequest(
      Map<String, dynamic> requestData,
      ) async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
        };
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final url = Uri.parse('$baseUrl/api/v1/services');

      final response = await http
          .post(url, headers: headers, body: json.encode(requestData))
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      final decoded = json.decode(response.body);

      return {
        "success": response.statusCode == 200 || response.statusCode == 201,
        "data": decoded['data'],
        "message": response.statusCode == 200 || response.statusCode == 201
            ? (decoded['message'] ?? "Service request created successfully")
            : ErrorHandler.sanitizeApiResponse(decoded, 'Failed to create service request. Please try again.'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> getDriverById(String driverId) async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/driver/$driverId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return {
          'success': true,
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': ErrorHandler.sanitizeApiResponse(responseData, 'Unable to load driver information. Please try again.'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> cancelServiceRequest(
      String serviceRequestId,
      ) async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
        };
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final url = Uri.parse('$baseUrl/api/v1/services/$serviceRequestId/cancel');

      final response = await http
          .patch(
        url,
        headers: headers,
        body: json.encode({'reason': 'User cancelled the request'}),
      )
          .timeout(const Duration(seconds: 30));

      final decoded = json.decode(response.body);

      return {
        "success": response.statusCode == 200 && decoded['success'] == true,
        "message": response.statusCode == 200 && decoded['success'] == true
            ? (decoded['message'] ?? "Service request cancelled successfully")
            : ErrorHandler.sanitizeApiResponse(decoded, 'Failed to cancel request. Please try again.'),
        "data": decoded,
      };
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>?> calculatePrice(String serviceType, double distanceKm, String token) async {
    try {
      final url = Uri.parse('$baseUrl/api/trip/rates/calculate');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'serviceType': serviceType,
          'distanceKm': distanceKm,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static String vehicleTypeToServiceType(String vehicleType) {
    switch (vehicleType) {
      case 'Two Wheeler':
        return 'two_wheeler';
      case 'Four Wheeler':
        return 'four_wheeler';
      case 'Heavy Vehicle':
        return 'heavy_truck';
      default:
        return 'N/A';
    }
  }
}