import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ReviewService {
  static const String _coreBaseUrl =
      'https://smiling-sparrow-proper.ngrok-free.app';
  static const String _rideBase = '$_coreBaseUrl/api/v1/services';
  static const String _mechanicBase = '$_coreBaseUrl/api/mechanic/requests';

  static Future<Map<String, String>> _headers() async {
    final token = await Auth.getToken();
    if (token == null) {
      throw Exception('Please log in again to continue.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _payload(double rating, String? comment) {
    final body = <String, dynamic>{'rating': rating};
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body['comment'] = trimmed;
    }
    return body;
  }

  static Never _throwHttpError(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      final message = decoded['message']?.toString();
      throw Exception(message ?? 'Failed to submit review.');
    } catch (_) {
      throw Exception(
        'Failed to submit review (status ${response.statusCode}).',
      );
    }
  }

  static void _ensureSuccess(http.Response response) {
    final status = response.statusCode;
    final isSuccess = status >= 200 && status < 300;
    if (!isSuccess) {
      _throwHttpError(response);
    }

    if (response.body.isEmpty) return;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == false) {
        final message =
            decoded['message']?.toString() ?? 'Failed to submit review.';
        throw Exception(message);
      }
    } catch (_) {
      // Ignore JSON parse failures for plain-text bodies
    }
  }

  static Future<void> submitUserReviewForRide(
    String requestId,
    double rating, {
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$_rideBase/$requestId/user-review'),
      headers: await _headers(),
      body: json.encode(_payload(rating, comment)),
    );

    _ensureSuccess(response);
  }

  static Future<void> submitUserReviewForMechanicJob(
    String requestId,
    double rating, {
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$_mechanicBase/$requestId/user-review'),
      headers: await _headers(),
      body: json.encode(_payload(rating, comment)),
    );

    _ensureSuccess(response);
  }
}
