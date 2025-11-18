import 'dart:async';
import 'dart:convert';
import 'package:driver/screens/continue_with_phone.dart';
import 'package:driver/screens/mechanic_registration/mechanic_registration.dart';
import 'package:driver/screens/splash_screen.dart';
import 'package:driver/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'ride_requese_dashboard/driver_requests_dashboard.dart';
import 'SubmissionUnderReviewPage.dart';
import 'driver_registration/screens/driver_registration_main_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String role;
  const OtpScreen({super.key, required this.phoneNumber, required this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Constants for UI configuration
  static const _appBarArrowImage = 'assets/images/arrow.png';
  static const _titleText = "Enter the code";
  static const _subtitleText = "We've sent you verification code";
  static const _buttonText = "Next";
  static const _otpLength = 5;
  static const _otpFieldWidth = 45.0;
  static const _otpOutlineBorderRadius = 5.0;

  // UI Styles
  static const _titleStyle = TextStyle(
    fontSize: 25,
    fontFamily: "UberMove",
    fontWeight: FontWeight.bold,
  );

  static const _subtitleStyle = TextStyle(
    fontSize: 15,
    fontFamily: "UberMove",
    fontWeight: FontWeight.normal,
  );

  static const _otpFieldStyle = TextStyle(fontSize: 17);
  static const _paddingAll = EdgeInsets.all(16.0);
  static const _bottomPadding = EdgeInsets.only(bottom: 20.0);

  static final _otpFieldStyleConfig = OtpFieldStyle(
    focusBorderColor: Colors.black,
  );

  // State variables
  final OtpFieldController _otpController = OtpFieldController();
  String _otp = "";
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onVerifyPressed() {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(milliseconds: 300), _verifyOtp);
  }

  Future<void> _verifyOtp() async {
    if (_isLoading || !mounted) {
      return;
    }

    if (_otp.isEmpty ||
        _otp.length != _otpLength ||
        !RegExp(r'^[0-9]+$').hasMatch(_otp)) {
      _showErrorMessage('Please enter a valid $_otpLength-digit OTP');
      if (_otp.isEmpty) {
        _otpController.clear();
        setState(() => _otp = "");
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.verifyOtp(
        widget.phoneNumber,
        _otp,
        widget.role,
      );

      if (response.statusCode == 200) {
        await _handleSuccessfulVerification(response.body);
      } else {
        await _handleErrorResponse(response);
      }
    } on TimeoutException {
      _showErrorMessage('Request timed out. Please check your connection.');
    } on http.ClientException {
      _showErrorMessage(
        'Network error. Please check your internet connection.',
      );
    } catch (error) {
      _showErrorMessage('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleErrorResponse(http.Response response) async {
    String errorMessage = 'Failed to verify OTP';

    switch (response.statusCode) {
      case 400:
        errorMessage = 'Invalid OTP format';
        break;
      case 401:
        errorMessage = 'Invalid or expired OTP';
        break;
      case 404:
        errorMessage = 'No OTP requested for this number';
        break;
      case 429:
        errorMessage = 'Too many attempts. Try again later';
        break;
      case 500:
        errorMessage = 'Server error. Try again later';
        break;
    }

    if (response.body.isNotEmpty) {
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {}
    }

    _showErrorMessage(errorMessage);

    if (response.statusCode == 400 || response.statusCode == 401) {
      _otpController.clear();
      if (mounted) setState(() => _otp = "");
    }
  }

  Future<void> _handleSuccessfulVerification(String responseBody) async {
    try {
      final responseData = jsonDecode(responseBody);
      final token = responseData['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token missing');
      }

      await Auth.saveToken(token);
      final latestStatuses = await _fetchLatestStatuses();
      _showSuccessMessage('OTP verified successfully');
      await _navigateBasedOnStatus(
        token,
        widget.role,
        latestStatuses: latestStatuses,
      );
    } catch (error) {
      _showErrorMessage('Error processing verification: $error');
    }
  }

  Future<Map<String, String>?> _fetchLatestStatuses() async {
    try {
      final response = await ApiService.getProfessionalStatus();
      if (response == null) return null;

      final driverStatus = response['driver']?['registrationStatus']
          ?.toString()
          .toLowerCase();
      final mechanicStatus = response['mechanic']?['registrationStatus']
          ?.toString()
          .toLowerCase();

      final statuses = <String, String>{};
      if (driverStatus != null && driverStatus.isNotEmpty) {
        statuses['driver'] = driverStatus;
      }
      if (mechanicStatus != null && mechanicStatus.isNotEmpty) {
        statuses['mechanic'] = mechanicStatus;
      }

      return statuses.isEmpty ? null : statuses;
    } catch (_) {
      return null;
    }
  }

  Future<void> _navigateBasedOnStatus(
    String token,
    String requestedRole, {
    Map<String, String>? latestStatuses,
  }) async {
    if (!mounted) return;

    // Decode JWT token
    final decodedToken = JwtDecoder.decode(token);

    // Extract roles, fallback to requested role
    final roles = List<String>.from(decodedToken['roles'] ?? [requestedRole]);

    // Extract statuses for roles
    final driverStatus =
        (decodedToken['driverRegistrationStatus']?.toString() ??
                decodedToken['registrationStatus']?.toString() ??
                'uncertain')
            .toLowerCase();
    final mechanicStatus =
        (decodedToken['mechanicRegistrationStatus']?.toString() ?? 'uncertain')
            .toLowerCase();

    // Map roles to their statuses
    final rolesStatuses = <String, String>{};
    if (latestStatuses != null && latestStatuses.isNotEmpty) {
      rolesStatuses.addAll(latestStatuses);
    }
    if (!rolesStatuses.containsKey('driver') && roles.contains('driver')) {
      rolesStatuses['driver'] = driverStatus;
    }
    if (!rolesStatuses.containsKey('mechanic') && roles.contains('mechanic')) {
      rolesStatuses['mechanic'] = mechanicStatus;
    }

    // Save statuses locally
    await _saveStatusesToPrefs(rolesStatuses);

    Widget? screen;

    // Special handling for "login" role
    if (requestedRole == 'login') {
      final statuses = rolesStatuses.values.toList();

      // Case 1: any approved - navigate to Dashboard
      if (statuses.contains('approved')) {
        screen = RideRequestsDashboard();
      }
      // Case 2: both pending - show Status screen
      else if (statuses.isNotEmpty &&
          statuses.every((status) => status == 'pending')) {
        screen = RegistrationStatusScreen(statuses: rolesStatuses);
      }
      // Case 3: both uncertain - show message and redirect to registration
      else if (statuses.isNotEmpty &&
          statuses.every((status) => status == 'uncertain')) {
        final scaffold = ScaffoldMessenger.of(context);

        scaffold.showSnackBar(
          SnackBar(
            content: const Text("Please register first"),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: "OK",
              onPressed: () {
                _navigateToScreen(ContinueWithPhone());
              },
            ),
          ),
        );

        // Fallback navigation if user ignores snackbar
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _navigateToScreen(ContinueWithPhone());
          }
        });

        return;
      }
    }

    // Priority 1: Any approved role goes directly to dashboard
    screen ??= rolesStatuses.values.any((status) => status == 'approved')
        ? RideRequestsDashboard()
        : null;

    // Priority 2: Mechanic registration flow
    screen ??=
        (requestedRole == 'mechanic' &&
            mechanicStatus != 'approved' &&
            mechanicStatus != 'rejected')
        ? MechanicRegistrationScreen()
        : null;

    // Priority 3: Driver registration flow
    screen ??=
        (requestedRole == 'driver' &&
            driverStatus != 'approved' &&
            driverStatus != 'rejected')
        ? DriverRegistrationApp()
        : null;

    // Priority 4: All roles rejected
    screen ??=
        (rolesStatuses.isNotEmpty &&
            rolesStatuses.values.every((status) => status == 'rejected'))
        ? RegistrationStatusScreen(statuses: rolesStatuses)
        : null;

    // Default: Go to phone login if nothing else matched
    screen ??= SplashScreen();

    _navigateToScreen(screen);
  }

  Future<void> _saveStatusesToPrefs(Map<String, String> rolesStatuses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove old values first
      await prefs.remove('driverStatus');
      await prefs.remove('mechanicStatus');

      // Save each status separately
      if (rolesStatuses.containsKey('driver')) {
        await prefs.setString('driverStatus', rolesStatuses['driver']!);
      }
      if (rolesStatuses.containsKey('mechanic')) {
        await prefs.setString('mechanicStatus', rolesStatuses['mechanic']!);
      }
    } catch (e) {}
  }

  void _navigateToScreen(Widget screen) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset(_appBarArrowImage, width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: _paddingAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(_titleText, style: _titleStyle),
              const SizedBox(height: 8),
              Text(
                '$_subtitleText\nto ${widget.phoneNumber}',
                style: _subtitleStyle,
              ),
              const SizedBox(height: 30),
              OTPTextField(
                controller: _otpController,
                length: _otpLength,
                width: MediaQuery.of(context).size.width,
                fieldWidth: _otpFieldWidth,
                style: _otpFieldStyle,
                textFieldAlignment: MainAxisAlignment.spaceAround,
                fieldStyle: FieldStyle.box,
                otpFieldStyle: _otpFieldStyleConfig,
                outlineBorderRadius: _otpOutlineBorderRadius,
                onChanged: (pin) => setState(() => _otp = pin),
                onCompleted: (pin) => setState(() => _otp = pin),
              ),
              const Spacer(),
              Padding(
                padding: _bottomPadding,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onVerifyPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            _buttonText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
