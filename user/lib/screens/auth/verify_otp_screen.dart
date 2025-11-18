import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:user/screens/auth/full_name_screen.dart';
import 'package:user/screens/enable_location_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_util.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String phoneNumber;

  const VerifyOtpScreen({super.key, required this.phoneNumber});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const appBarArrowImage = 'assets/images/arrow.png';
  static const titleText = "Enter the code";
  static const subtitleText = "We've sent you verification code";
  static const buttonText = "Next";

  static const TextStyle titleStyle = TextStyle(
    fontSize: 25,
    fontFamily: "UberMove",
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 15,
    fontFamily: "UberMove",
    fontWeight: FontWeight.normal,
  );

  static const TextStyle otpFieldStyle = TextStyle(fontSize: 17);

  static const EdgeInsets paddingAll = EdgeInsets.all(16.0);
  static const EdgeInsets bottomPadding = EdgeInsets.only(bottom: 20.0);

  static const int otpLength = 5;
  static const double otpFieldWidth = 45;
  static const double otpOutlineBorderRadius = 5;
  static final OtpFieldStyle otpFieldStyleConfig = OtpFieldStyle(
    focusBorderColor: Colors.black,
  );

  final OtpFieldController otpFieldController = OtpFieldController();
  final ApiService _apiService = ApiService();

  String otp = "";
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Validates OTP input before submission
  bool _validateOtp() {
    if (otp.isEmpty) {
      _showErrorMessage('Please enter the OTP');
      return false;
    }

    if (otp.length != otpLength) {
      _showErrorMessage('Please enter a complete $otpLength-digit OTP');
      return false;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(otp)) {
      _showErrorMessage('OTP should contain only numbers');
      return false;
    }

    return true;
  }

  // Handles OTP verification with server
  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    if (!_validateOtp()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.verifyOtp(widget.phoneNumber, otp);

      if (!mounted) return;

      if (result['success'] == true) {
        final token = result['token'] as String;
        final requiresFullName = result['requiresFullName'] as bool;

        await Auth.saveToken(token);
        _showSuccessMessage('OTP verified successfully');

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        if (requiresFullName) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FullNameScreen(phoneNumber: widget.phoneNumber),
            ),
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => EnableLocationScreen()),
                (route) => false,
          );
        }
      } else {
        final message = result['message'] as String;
        _showErrorMessage(message);
        _clearOtpFields();
      }
    } on TimeoutException {
      if (mounted) {
        _showErrorMessage('Request timed out. Please check your connection.');
      }
    } on SocketException {
      if (mounted) {
        _showErrorMessage('Network error. Please check your internet connection.');
      }
    } on FormatException {
      if (mounted) {
        _showErrorMessage('Invalid response format from server.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Clears OTP input fields for security after failed attempts
  void _clearOtpFields() {
    otpFieldController.clear();
    setState(() {
      otp = "";
    });
  }

  // Debounced button handler to prevent multiple rapid submissions
  void _onButtonPressed() {
    if (_debounceTimer?.isActive ?? false) return;

    _debounceTimer = Timer(const Duration(milliseconds: 300), _verifyOtp);
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    SnackBarUtil.showError(context, message);
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    SnackBarUtil.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset(appBarArrowImage, width: 25, height: 25),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: paddingAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Text(titleText, textAlign: TextAlign.center, style: titleStyle),
            const SizedBox(height: 10),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: subtitleStyle,
            ),
            const SizedBox(height: 30),
            OTPTextField(
              length: otpLength,
              width: MediaQuery.of(context).size.width,
              fieldWidth: otpFieldWidth,
              style: otpFieldStyle,
              textFieldAlignment: MainAxisAlignment.spaceEvenly,
              fieldStyle: FieldStyle.box,
              outlineBorderRadius: otpOutlineBorderRadius,
              otpFieldStyle: otpFieldStyleConfig,
              controller: otpFieldController,
              onChanged: (String code) {
                setState(() {
                  otp = code;
                });
              },
              onCompleted: (String code) {
                setState(() {
                  otp = code;
                });
                _onButtonPressed();
              },
            ),
            const Spacer(),
            Padding(
              padding: bottomPadding,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onButtonPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      buttonText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: "UberMove",
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}