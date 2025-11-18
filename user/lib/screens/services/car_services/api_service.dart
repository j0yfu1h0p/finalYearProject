import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:user/screens/services/car_services/service_request_confirmation_screen.dart';
import 'package:user/screens/services/car_services/waiting_for_mechanic_screen.dart';
import 'dart:convert';

import '../../../services/auth_service.dart';
import '../../../utils/error_handler.dart';
import 'mechanic_provider.dart';

class ApiService {
  static const String baseUrl = 'https://smiling-sparrow-proper.ngrok-free.app';
  static const Duration requestTimeout = Duration(seconds: 30);

  // Calculates service price based on service type
  static Future<Map<String, dynamic>> calculatePrice(
      String serviceType,
      String token,
      ) async {
    if (serviceType.isEmpty || token.isEmpty) {
      return {
        'success': false,
        'message': 'Invalid input parameters',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trip/rates/calculate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'serviceType': serviceType}),
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));

        if (responseData is! Map<String, dynamic>) {
          return {
            'success': false,
            'message': 'Invalid response format from server',
          };
        }

        return {
          'success': true,
          ...responseData,
        };
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': ErrorHandler.sanitizeApiResponse(
              responseData,
              'Unable to calculate price. Please try again.'
          ),
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timeout. Please check your connection.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Invalid response format from server.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }

  // Creates a new service request with location and pricing details
  static Future<Map<String, dynamic>> createServiceRequest(
      String serviceType,
      List<double> coordinates,
      String notes,
      double price,
      String token,
      ) async {
    // Input validation
    if (serviceType.isEmpty || token.isEmpty) {
      return {
        'success': false,
        'message': 'Service type and authentication token are required',
      };
    }

    if (coordinates.length != 2) {
      return {
        'success': false,
        'message': 'Invalid coordinates provided',
      };
    }

    if (price <= 0) {
      return {
        'success': false,
        'message': 'Invalid price amount',
      };
    }

    // Sanitize input data
    final sanitizedNotes = notes.substring(0, notes.length.clamp(0, 500));
    final sanitizedCoordinates = [
      coordinates[0].clamp(-90.0, 90.0), // Latitude bounds
      coordinates[1].clamp(-180.0, 180.0) // Longitude bounds
    ];

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/mechanic/requests/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'serviceType': serviceType,
          'userLocation': {
            'type': 'Point',
            'coordinates': sanitizedCoordinates
          },
          'notes': sanitizedNotes,
          'priceQuote': {
            'amount': price,
            'currency': 'PKR'
          },
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 201) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));

        if (responseData is! Map<String, dynamic>) {
          return {
            'success': false,
            'message': 'Invalid response format from server',
          };
        }

        return {
          'success': true,
          'data': responseData,
        };
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': ErrorHandler.sanitizeApiResponse(
              responseData,
              'Failed to create service request. Please try again.'
          ),
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timeout. Please check your connection.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Invalid response format from server.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': ErrorHandler.sanitizeErrorMessage(e),
      };
    }
  }
}