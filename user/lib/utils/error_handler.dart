import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

class ErrorHandler {
  static String sanitizeErrorMessage(dynamic error) {
    String errorMessage = error.toString();

    if (error is SocketException) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }

    if (error is HttpException) {
      return 'Service temporarily unavailable. Please try again later.';
    }

    if (error is FormatException) {
      return 'Invalid data received. Please try again.';
    }

    if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    }

    if (error is DioException) {
      return _handleDioException(error);
    }

    errorMessage = _removeSensitiveInfo(errorMessage);

    if (_isTechnicalError(errorMessage)) {
      return 'An unexpected error occurred. Please try again later.';
    }

    return errorMessage;
  }

  static String _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Invalid request. Please check your input and try again.';
          case 401:
            return 'Authentication failed. Please log in again.';
          case 403:
            return 'Access denied. You don\'t have permission to perform this action.';
          case 404:
            return 'Service not found. Please try again later.';
          case 429:
            return 'Too many requests. Please wait a moment and try again.';
          case 500:
          case 502:
          case 503:
          case 504:
            return 'Server error. Please try again later.';
          default:
            return 'Service temporarily unavailable. Please try again later.';
        }

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.connectionError:
        return 'Network connection failed. Please check your internet connection.';

      case DioExceptionType.badCertificate:
        return 'Security certificate error. Please try again later.';

      case DioExceptionType.unknown:
      default:
        return 'An unexpected error occurred. Please try again later.';
    }
  }

  static String _removeSensitiveInfo(String message) {
    message = message.replaceAll(RegExp(r'https?://[^\s]+'), '[URL_REMOVED]');
    message = message.replaceAll(RegExp(r'/api/[^\s]*'), '[ENDPOINT_REMOVED]');
    message = message.replaceAll(RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), '[IP_REMOVED]');
    message = message.replaceAll(RegExp(r':\d{2,5}'), '[PORT_REMOVED]');
    message = message.replaceAll(RegExp(r'[A-Za-z]:\\[^\s]*'), '[PATH_REMOVED]');
    message = message.replaceAll(RegExp(r'/[a-zA-Z0-9_/.-]+'), '[PATH_REMOVED]');
    message = message.replaceAll(RegExp(r'at [^\n]+'), '');
    message = message.replaceAll(RegExp(r'#\d+ [^\n]+'), '');
    message = message.replaceAll(RegExp(r'[a-zA-Z0-9-]+\.ngrok[^\s]*'), '[SERVICE_URL]');
    message = message.replaceAll(RegExp(r'\s+'), ' ').trim();

    return message;
  }

  static bool _isTechnicalError(String message) {
    final technicalKeywords = [
      'Exception',
      'Error:',
      'RangeError',
      'ArgumentError',
      'StateError',
      'TypeError',
      'NoSuchMethodError',
      'SocketException',
      'HttpException',
      'FormatException',
      'Instance of',
      'flutter',
      'dart:',
      'lib/',
      'package:',
      '[URL_REMOVED]',
      '[ENDPOINT_REMOVED]',
    ];

    return technicalKeywords.any((keyword) =>
      message.toLowerCase().contains(keyword.toLowerCase()));
  }

  static String sanitizeApiResponse(dynamic response, [String? fallbackMessage]) {
    try {
      if (response is Map<String, dynamic>) {
        String? message = response['message'] ??
                         response['error'] ??
                         response['detail'] ??
                         response['description'];

        if (message != null && message.isNotEmpty) {
          return _removeSensitiveInfo(message);
        }
      }

      return fallbackMessage ?? 'An error occurred. Please try again.';
    } catch (e) {
      return fallbackMessage ?? 'An error occurred. Please try again.';
    }
  }

  static Map<String, dynamic> createSafeError(dynamic error, String userMessage) {
    return {
      'userMessage': userMessage,
      'sanitizedError': sanitizeErrorMessage(error),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
