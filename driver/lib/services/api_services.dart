// lib/services/api_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/driver_request_screen_model.dart';
import '../models/mechanic_service_request_model.dart';
import 'auth_service.dart';

class ApiService {
  // Base URL
  static const String _baseUrl =
      'https://smiling-sparrow-proper.ngrok-free.app';

  // Timeout
  static const Duration _timeout = Duration(seconds: 10);

  // Headers
  static const String _contentTypeHeader = 'Content-Type';
  static const String _authorizationHeader = 'Authorization';
  static const String _contentTypeJson = 'application/json';
  static const String _bearerPrefix = 'Bearer ';

  // ImgBB API
  static const String _imgBbApiKey = '5901839607895f07bae1636c9ff8fb4e';
  static const String _imgBbUploadUrl = 'https://api.imgbb.com/1/upload';

  static get baseUrl => _baseUrl;

  // Headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final token = await Auth.getToken();
    return {
      _contentTypeHeader: _contentTypeJson,
      if (token != null) _authorizationHeader: '$_bearerPrefix$token',
    };
  }

  // Refresh token
  static Future<String?> refreshToken(String oldToken) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/driver/auth/refresh-token'),
            headers: {
              _contentTypeHeader: _contentTypeJson,
              _authorizationHeader: '$_bearerPrefix$oldToken',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['token'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Send OTP with detailed handling
  static Future<Map<String, dynamic>> sendOtp(
    String phoneNumber,
    String role,
  ) async {
    try {
      String endpoint;

      // Decide endpoint based on role
      if (role == "mechanic") {
        endpoint = "mechanic/auth/send-otp";
      } else if (role == "driver") {
        endpoint = "driver/auth/send-otp";
      } else if (role == "login") {
        endpoint = "professional/auth/send-otp-unified";
      } else {
        throw ArgumentError("Invalid role provided: $role");
      }

      // Prepare request body
      final requestBody = jsonEncode({'phoneNumber': phoneNumber});

      // Make POST request
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/$endpoint'),
            headers: {
              _contentTypeHeader: _contentTypeJson,
              _authorizationHeader: '$_bearerPrefix${await Auth.getToken()}',
            },
            body: requestBody,
          )
          .timeout(_timeout);

      if (response.body.isEmpty) {
        throw const FormatException('Empty response from server');
      }

      final responseData = jsonDecode(response.body);

      // Wrap response
      return {
        'statusCode': response.statusCode,
        'data': responseData,
        'success': response.statusCode == 200,
      };
    } on TimeoutException {
      rethrow;
    } on SocketException {
      rethrow;
    } on FormatException {
      rethrow;
    } on HttpException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  static Future<http.Response> getMechanicRecentBookings() async {
    final token = await Auth.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/mechanic/bookings/recent'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    return response;
  }

  // Error message handler
  static String getErrorMessage(
    int statusCode,
    Map<String, dynamic> responseData,
  ) {
    switch (statusCode) {
      case 400:
        return responseData['message'] ?? 'Invalid phone number or request';
      case 401:
        return responseData['message'] ?? 'Authentication failed';
      case 429:
        return responseData['message'] ??
            'Too many requests. Please try again later';
      case 500:
        return responseData['message'] ??
            'Server error. Please try again later';
      default:
        return responseData['message'] ??
            'Failed to send OTP. Please try again';
    }
  }

  // Verify OTP based on role
  static Future<http.Response> verifyOtp(
    String phoneNumber,
    String otp,
    String role,
  ) async {
    try {
      // Choose endpoint based on role
      final String endpoint;
      if (role == 'mechanic') {
        endpoint = '$_baseUrl/api/mechanic/auth/verify-otp';
      } else if (role == 'driver') {
        endpoint = '$_baseUrl/api/driver/auth/verify-otp';
      } else if (role == 'login') {
        endpoint = '$_baseUrl/api/professional/auth/verify-otp-unified';
      } else {
        throw Exception('Invalid role: $role');
      }

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {"Content-Type": _contentTypeJson},
            body: json.encode({'phoneNumber': phoneNumber, 'otp': otp}),
          )
          .timeout(_timeout);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Get pending mechanic service requests
  static Future<List<MechanicServiceRequest>>
  getPendingMechanicRequests() async {
    try {
      final token = await Auth.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/mechanic/requests/pending/nearby'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => MechanicServiceRequest.fromJson(json))
            .toList();
      } else {
        throw Exception(
          'Failed to load mechanic requests: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to load mechanic requests: $e');
    }
  }

  // Accept mechanic service request
  static Future<Map<String, dynamic>> acceptMechanicRequest(
    String requestId,
  ) async {
    try {
      final token = await Auth.getToken();
      final url = '$baseUrl/api/mechanic/requests/$requestId/accept';

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to accept mechanic request: ${response.statusCode} - ${response.body}',
        );
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      throw Exception('Failed to accept mechanic request: $e');
    }
  }

  static Future<http.Response> getRecentBooking() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/api/history/driver'), headers: headers)
          .timeout(_timeout);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Get driver profile
  static Future<Map<String, dynamic>?> getDriverProfile() async {
    final token = await Auth.getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/api/driver/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProfessionalStatus() async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey(_authorizationHeader)) {
        return null;
      }

      final response = await http
          .get(Uri.parse('$_baseUrl/api/professional/status'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getMechanicProfile() async {
    final token = await Auth.getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/api/mechanic/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['data'];
    } else {
      return null;
    }
  }

  // Register driver
  static Future<Map<String, dynamic>?> registerDriver(
    Map<String, dynamic> driverData,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/driver/register'),
            headers: headers,
            body: json.encode(driverData),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if CNIC exists
  static Future<bool> checkCnicExists(String cnic) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/driver/check-cnic?cnic=$cnic'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if license exists
  static Future<bool> checkLicenseExists(String license) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/driver/check-license?license=$license'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if plate exists
  static Future<bool> checkPlateExists(String plate) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/driver/check-plate?plate=$plate'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get pending updates
  static Future<Map<String, dynamic>?> getPendingUpdates(
    DateTime lastSeen,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/driver/pending-updates?lastSeen=${lastSeen.toIso8601String()}',
            ),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get nearby pending requests
  static Future<List<ServiceRequest>> getNearbyPendingRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final token = await Auth.getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final requestBody = jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      });

      final queryParams = '?radiusKm=$radiusKm';

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/services/nearby-requests$queryParams'),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> requestsData = data['data'];
          return requestsData
              .map((json) => ServiceRequest.fromJson(json))
              .toList();
        } else {
          throw Exception(
            'Failed to load nearby requests: ${data['message'] ?? 'Unknown error'}',
          );
        }
      } else if (response.statusCode == 400) {
        throw Exception('Location data is required');
      } else if (response.statusCode == 401) {
        await Auth.removeToken();
        throw Exception('Authentication failed: Please login again');
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get pending ride requests
  static Future<List<ServiceRequest>> getPendingRequests() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/services/pool'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> requestsData = data['data'];
          return requestsData
              .map((json) => ServiceRequest.fromJson(json))
              .toList();
        } else {
          throw Exception(
            'Failed to load requests: ${data['message'] ?? 'Unknown error'}',
          );
        }
      } else if (response.statusCode == 401) {
        await Auth.removeToken();
        throw Exception('Authentication failed: Please login again');
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Accept ride request
  static Future<void> acceptRequest(String requestId) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/api/v1/services/$requestId/accept';

      final response = await http
          .patch(Uri.parse(url), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Failed to accept request');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Generic authenticated POST request
  static Future<http.Response> makeAuthenticatedPost(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _getHeaders();
    return await http
        .post(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: headers,
          body: json.encode(body ?? {}),
        )
        .timeout(_timeout);
  }

  // Generic authenticated GET request
  static Future<http.Response> makeAuthenticatedGet(String endpoint) async {
    final headers = await _getHeaders();
    return await http
        .get(Uri.parse('$_baseUrl/$endpoint'), headers: headers)
        .timeout(_timeout);
  }

  // Get user by ID
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/users/$userId'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'user': data['user']};
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch user data',
          };
        }
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'User not found'};
      } else {
        return {
          'success': false,
          'message':
              'Failed to fetch user data. Server responded with ${response.statusCode}',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timeout. Please check your internet connection.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch user data: $e'};
    }
  }
}

// Image upload functions
Future<String> uploadImage(File imageFile) async {
  try {
    final url = '${ApiService._imgBbUploadUrl}?key=${ApiService._imgBbApiKey}';

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    var request = http.MultipartRequest('POST', Uri.parse(url));

    request.fields['image'] = base64Image;

    String fileName = imageFile.path.split('/').last;
    request.fields['name'] = fileName;

    var response = await request.send();

    if (response.statusCode == 200) {
      var respBody = await response.stream.bytesToString();
      var data = json.decode(respBody);

      if (data['success'] == true) {
        return data['data']['url'];
      } else {
        throw Exception('Upload failed: ${data['error']['message']}');
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Image upload failed: $e');
  }
}

// Alternative method using direct HTTP POST
Future<String> uploadImageDirect(File imageFile) async {
  try {
    final url = '${ApiService._imgBbUploadUrl}?key=${ApiService._imgBbApiKey}';

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final formData = {
      'image': base64Image,
      'name': imageFile.path.split('/').last,
    };

    final response = await http.post(Uri.parse(url), body: formData);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success'] == true) {
        return data['data']['url'];
      } else {
        throw Exception('Upload failed: ${data['error']['message']}');
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Image upload failed: $e');
  }
}

// Batch upload function for multiple images
Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
  List<String> uploadedUrls = [];

  for (File imageFile in imageFiles) {
    try {
      String url = await uploadImage(imageFile);
      uploadedUrls.add(url);
    } catch (e) {
      rethrow;
    }
  }

  return uploadedUrls;
}

// Function to validate image before upload
bool validateImage(File imageFile) {
  // Check file size (32MB limit for ImgBB)
  final fileSizeInBytes = imageFile.lengthSync();
  final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

  if (fileSizeInMB > 32.0) {
    return false;
  }

  // Check file extension
  final extension = imageFile.path.split('.').last.toLowerCase();
  return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
}

// Legacy functions for backward compatibility
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

Future<http.Response> makeAuthenticatedGetRequest(String url) async {
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
