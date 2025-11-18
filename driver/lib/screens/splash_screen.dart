import 'dart:async';
import 'dart:convert';

import 'package:driver/screens/role_selection.dart';
import 'package:driver/screens/sign_in.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_services.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../models/driver_request_screen_model.dart';
import 'driver_registration/screens/driver_registration_main_screen.dart';
import 'ride_requese_dashboard/driver_requests_dashboard.dart';
import 'SubmissionUnderReviewPage.dart';
import 'continue_with_phone.dart';
import 'mechanic_registration/mechanic_registration.dart';
import 'PassengerDetailsScreen.dart';
import 'ride_requese_dashboard/user_track_screen_mech.dart';

// Authentication result data class
class AuthResult {
  final bool isValid;
  final String registrationStatus;
  final Map<String, dynamic>? statusResponse;

  AuthResult({
    required this.isValid,
    this.registrationStatus = 'pending',
    this.statusResponse
  });

  factory AuthResult.invalid() => AuthResult(isValid: false);
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    await _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Check authentication status
      if (!await Auth.hasToken()) {
        _redirectToLogin();
        return;
      }

      final token = await Auth.getToken();
      if (token == null || token.isEmpty) {
        _redirectToLogin();
        return;
      }

      // Verify token and get current status using the unified endpoint
      final authResult = await _verifyTokenAndCheckStatus(token);
      if (!authResult.isValid) {
        _redirectToLogin();
        return;
      }

      // Navigate based on current status
      _navigateBasedOnStatus(authResult.statusResponse);
    } catch (e) {
      _redirectToLogin();
    }
  }

  Future<void> _saveStatusesToPrefs(Map<String, String> rolesStatuses) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove old values first
      await prefs.remove('driverStatus');
      await prefs.remove('mechanicStatus');

      // Save new statuses only if present
      if (rolesStatuses.containsKey('driver')) {
        await prefs.setString('driverStatus', rolesStatuses['driver']!);
      }
      if (rolesStatuses.containsKey('mechanic')) {
        await prefs.setString('mechanicStatus', rolesStatuses['mechanic']!);
      }
    } catch (e) {}
  }

  Future<AuthResult> _verifyTokenAndCheckStatus(String token) async {
    if (_isCheckingStatus) {
      return AuthResult.invalid();
    }
    _isCheckingStatus = true;

    try {
      // Check if token is expired
      if (JwtDecoder.isExpired(token)) {
        final refreshedToken = await _refreshToken(token);
        if (refreshedToken == null) {
          return AuthResult.invalid();
        }
        token = refreshedToken;
        await Auth.setToken(token);
      }

      // Call unified backend
      final statusResponse = await _checkProfessionalStatus(token);
      if (statusResponse == null) {
        return AuthResult.invalid();
      }

      // Extract roles independently
      final driverStatus = statusResponse['driver']?['registrationStatus'];
      final mechanicStatus = statusResponse['mechanic']?['registrationStatus'];

      // Decide overall validity
      final isValid = driverStatus != null || mechanicStatus != null;

      return AuthResult(
        isValid: isValid,
        registrationStatus: driverStatus ?? mechanicStatus ?? 'pending',
        statusResponse: statusResponse,
      );
    } catch (e) {
      return AuthResult.invalid();
    } finally {
      _isCheckingStatus = false;
    }
  }

  Future<String?> _refreshToken(String oldToken) async {
    try {
      final newToken = await ApiService.refreshToken(oldToken);
      return newToken;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _checkProfessionalStatus(String token) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final url = '${ApiService.baseUrl}/api/professional/status';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        return decodedResponse;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _redirectToLogin() {
    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ContinueWithPhone()),
    );
  }

  void _navigateBasedOnStatus(Map<String, dynamic>? statusResponse) async {
    if (!mounted || statusResponse == null) return;

    final driverStatus = (statusResponse['driver']?['registrationStatus']?.toString() ?? 'uncertain').toLowerCase();
    final mechanicStatus = (statusResponse['mechanic']?['registrationStatus']?.toString() ?? 'uncertain').toLowerCase();

    final rolesStatuses = <String, String>{
      'driver': driverStatus,
      'mechanic': mechanicStatus,
    };

    await _saveStatusesToPrefs(rolesStatuses);

    // Check for active trips/jobs before navigating
    if (rolesStatuses.values.contains('approved')) {
      // Check for active trip (driver role)
      if (driverStatus == 'approved') {
        final activeTrip = await _checkActiveTrip();
        if (activeTrip != null && mounted) {
          _navigateToActiveTrip(activeTrip);
          return;
        }
      }

      // Check for active mechanic job (mechanic role)
      if (mechanicStatus == 'approved') {
        final activeJob = await _checkActiveMechanicJob();
        if (activeJob != null && mounted) {
          _navigateToActiveMechanicJob(activeJob);
          return;
        }
      }

      // No active trips/jobs, go to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideRequestsDashboard()),
      );
      return;
    }

    // Handle other statuses (pending, rejected, uncertain)
    Widget screen;
    if (rolesStatuses.values.every((status) => status == 'uncertain')) {
      screen = ContinueWithPhone();
    } else if (mechanicStatus == 'pending') {
      screen = RegistrationStatusScreen(statuses: rolesStatuses);
    } else if (driverStatus == 'pending') {
      screen = RegistrationStatusScreen(statuses: rolesStatuses);
    } else if (rolesStatuses.values.every((status) => status == 'rejected')) {
      screen = RegistrationStatusScreen(statuses: rolesStatuses);
    } else {
      screen = RegistrationStatusScreen(statuses: rolesStatuses);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // Check for active driver trip
  Future<Map<String, dynamic>?> _checkActiveTrip() async {
    try {
      final token = await Auth.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/driver/active-trip'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hasActiveTrip'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check for active mechanic job
  Future<Map<String, dynamic>?> _checkActiveMechanicJob() async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/mechanic/requests/active-job'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['hasActiveJob'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Navigate to active trip screen
  void _navigateToActiveTrip(Map<String, dynamic> tripData) {
    try {
      // Safely extract pickup location
      final pickupData = tripData['pickupLocation'];
      PickupLocation pickupLocation;

      if (pickupData != null && pickupData is Map) {
        final pickupMap = Map<String, dynamic>.from(pickupData);
        pickupLocation = PickupLocation.fromJson(pickupMap);
      } else {
        pickupLocation = PickupLocation(
          address: '',
          coordinates: Coordinates(lat: 0.0, lng: 0.0),
        );
      }

      // Safely extract destination
      final destinationData = tripData['destination'];
      Destination destination;

      if (destinationData != null && destinationData is Map) {
        final destMap = Map<String, dynamic>.from(destinationData);
        destination = Destination.fromJson(destMap);
      } else {
        destination = Destination(
          address: '',
          coordinates: Coordinates(lat: 0.0, lng: 0.0),
        );
      }

      // Create ServiceRequest object from trip data
      final serviceRequest = ServiceRequest(
        id: tripData['_id']?.toString() ?? '',
        userId: (() {
          final userIdData = tripData['userId'];
          if (userIdData is Map) {
            return userIdData['_id']?.toString() ?? '';
          } else if (userIdData is String) {
            return userIdData;
          }
          return '';
        })(),
        driverId: (() {
          final driverIdData = tripData['driverId'];
          if (driverIdData is Map) {
            return driverIdData['_id']?.toString() ?? '';
          } else if (driverIdData is String) {
            return driverIdData;
          }
          return '';
        })(),
        vehicleType: tripData['vehicleType']?.toString() ?? '',
        pickupLocation: pickupLocation,
        destination: destination,
        distance: (tripData['distance'] as num?)?.toDouble() ?? 0.0,
        duration: (tripData['duration'] as num?)?.toInt() ?? 0,
        rate: (tripData['rate'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (tripData['totalAmount'] as num?)?.toDouble() ?? 0.0,
        status: tripData['status']?.toString() ?? '',
        createdAt: DateTime.tryParse(tripData['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

      // Get socket service instance and connect
      final socketService = SocketService.getInstance();

      // Ensure socket is connected before navigating
      _ensureSocketConnected(socketService).then((_) {
        // Navigate to passenger details screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SimplePassengerDetailsScreen(
              request: serviceRequest,
              socketService: socketService,
            ),
          ),
        );
      });
    } catch (e, stackTrace) {
      // Fallback to dashboard if navigation fails
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideRequestsDashboard()),
      );
    }
  }

  // Ensure socket connection is established
  Future<void> _ensureSocketConnected(SocketService socketService) async {
    try {
      if (!socketService.isConnected) {
        final token = await Auth.getToken();
        if (token != null) {
          final decoded = JwtDecoder.decode(token);
          final driverId = decoded['id']?.toString();
          if (driverId != null) {
            await socketService.connect(driverId);
            // Wait for connection to establish
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
    } catch (e) {}
  }

  // Navigate to active mechanic job screen
  void _navigateToActiveMechanicJob(Map<String, dynamic> jobData) {
    try {
      // Extract mechanic data - handle both string ID and object
      final mechanicIdData = jobData['mechanicId'];
      final mechanicData = {
        '_id': mechanicIdData is String ? mechanicIdData : (mechanicIdData?['_id'] ?? ''),
        'personal_info': mechanicIdData is Map ? mechanicIdData['personal_info'] : null,
        'phoneNumber': mechanicIdData is Map ? mechanicIdData['phoneNumber'] : null,
      };

      // Extract user data - should be an object with _id, fullName, phoneNumber
      final userIdData = jobData['userId'];
      final userData = {
        '_id': userIdData is Map ? (userIdData['_id'] ?? '') : userIdData?.toString() ?? '',
        'name': userIdData is Map ? (userIdData['fullName'] ?? userIdData['name'] ?? 'Customer') : 'Customer',
        'phone': userIdData is Map ? (userIdData['phoneNumber'] ?? userIdData['phone'] ?? '') : '',
      };

      // Navigate to UserTrackScreenMech
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserTrackScreenMech(
            mechanicData: mechanicData,
            serviceRequest: jobData,
            userData: userData,
          ),
        ),
      );
    } catch (e, stackTrace) {
      // Fallback to dashboard if navigation fails
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideRequestsDashboard()),
      );
    }
  }

  void _showStatusScreen(Map<String, dynamic> statusResponse) {
    // Extract both driver and mechanic statuses or use default values
    final driverStatus = statusResponse['driver']?['registrationStatus'] ?? 'not_registered';
    final mechanicStatus = statusResponse['mechanic']?['registrationStatus'] ?? 'not_registered';

    // Pass both statuses to RegistrationStatusScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationStatusScreen(
          statuses: {
            'driver': driverStatus,
            'mechanic': mechanicStatus,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "MyAutoBridge",
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontFamily: "UberMove",
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 150),
              child: Text(
                "Professional",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontFamily: "UberMove",
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
