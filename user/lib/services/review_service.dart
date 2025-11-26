import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_service.dart';
import '../utils/error_handler.dart';

class ReviewService {
  static const _baseUrl = ApiService.baseUrl;

  Future<void> submitRideReview({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    await _post(
      uri: Uri.parse('$_baseUrl/api/v1/services/$requestId/review'),
      rating: rating,
      comment: comment,
    );
  }

  Future<void> submitMechanicReview({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    await _post(
      uri: Uri.parse('$_baseUrl/api/mechanic/requests/$requestId/review'),
      rating: rating,
      comment: comment,
    );
  }

  Future<void> _post({
    required Uri uri,
    required int rating,
    String? comment,
  }) async {
    final token = await Auth.getToken();
    if (token == null) {
      throw Exception('You need to sign in again to leave a review.');
    }

    final payload = <String, dynamic>{'rating': rating};

    final trimmedComment = comment?.trim();
    if (trimmedComment != null && trimmedComment.isNotEmpty) {
      payload['comment'] = trimmedComment;
    }

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      if (response.body.isNotEmpty) {
        try {
          final decodedBody = json.decode(response.body);
          final message = ErrorHandler.sanitizeApiResponse(
            decodedBody,
            'Unable to submit review (${response.statusCode}).',
          );
          throw Exception(message);
        } catch (_) {
          throw Exception('Unable to submit review (${response.statusCode}).');
        }
      }

      throw Exception('Unable to submit review (${response.statusCode}).');
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('Unable to submit review. Please try again.');
    }
  }
}
