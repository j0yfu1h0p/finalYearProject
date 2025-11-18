import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/services.dart';

import '../services/api_services.dart';
import '../utils/snackbar_util.dart';
import 'continue_with_phone.dart';
import 'otp.dart';

class AuthService {
  // Phone number validation
  static bool isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.isEmpty) return false;
    if (cleanNumber.length < 7 || cleanNumber.length > 15) {
      return false;
    }
    return true;
  }

  // Format phone number with country code
  static String formatPhoneNumber(String countryCode, String phoneNumber) {
    return '$countryCode${phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}';
  }
}

class SignIn extends StatefulWidget {
  final String role; // driver, mechanic, or login

  const SignIn({super.key, required this.role});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  String countryCode = "+92";
  String flagEmoji = "🇵🇰";
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  // Constants
  static const appBarArrowImage = 'assets/images/arrow.png';
  static const titleText = "Join us via phone number";
  static const subtitleText = "We'll text a code to verify your phone";
  static const buttonText = "Next";

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Show error snackbar
  void _showErrorSnackbar(String message) {
    if (mounted) {
      SnackBarUtil.showError(context, message);
    }
  }

  // Show success snackbar
  void _showSuccessSnackbar(String message) {
    if (mounted) {
      SnackBarUtil.showSuccess(context, message);
    }
  }

  // Handle OTP sending
// Handle OTP sending
  Future<void> _sendOTP(String role) async {
    final String phoneNumber = _phoneController.text.trim();

    // Validate phone number
    if (phoneNumber.isEmpty) {
      _showErrorSnackbar('Please enter a phone number');
      return;
    }

    if (!AuthService.isValidPhoneNumber(phoneNumber)) {
      _showErrorSnackbar('Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String fullPhoneNumber =
      AuthService.formatPhoneNumber(countryCode, phoneNumber);

      //  Send OTP based on role
      final response = await ApiService.sendOtp(fullPhoneNumber, role);

      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccessSnackbar('OTP sent successfully');

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                phoneNumber: fullPhoneNumber,
                role: role,
              ),
            ),
          );
        }
      } else {
        final errorMessage = ApiService.getErrorMessage(
          response['statusCode'],
          response['data'],
        );

        // ✅ Special case: login (unified OTP error)
        if (role == "login") {
          if (mounted) {
            SnackBarUtil.showError(context, errorMessage);
          }
        } else {
          _showErrorSnackbar(errorMessage);
        }
      }
    } on TimeoutException {
      if (mounted) _showErrorSnackbar('Request timeout. Please try again');
    } on SocketException {
      if (mounted) {
        _showErrorSnackbar('Network error. Please check your internet connection');
      }
    } on FormatException {
      if (mounted) {
        _showErrorSnackbar('Invalid response from server. Please try again');
      }
    } on HttpException {
      if (mounted) _showErrorSnackbar('Connection error. Please try again');
    } catch (error) {
      if (mounted) {
        _showErrorSnackbar('An unexpected error occurred. Please try again');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset(appBarArrowImage, width: 25, height: 25),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 25,
                                fontFamily: "UberMove",
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: "UberMove",
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 300,
                              height: 45,
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                cursorColor: Colors.black,
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                    const BorderSide(color: Colors.black),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                    const BorderSide(color: Colors.black),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  prefixIcon: Container(
                                    padding: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 0,
                                      left: 14,
                                      right: 8,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        showCountryPicker(
                                          context: context,
                                          showPhoneCode: true,
                                          onSelect: (Country country) {
                                            setState(() {
                                              countryCode =
                                              "+${country.phoneCode}";
                                              flagEmoji = country.flagEmoji;
                                            });
                                          },
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            flagEmoji,
                                            style:
                                            const TextStyle(fontSize: 22),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            countryCode,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                      ),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            // ✅ FIX: wrap in closure to pass role
                            onPressed: _isLoading
                                ? null
                                : () => _sendOTP(widget.role),
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 15.0),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      Colors.white),
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
              ),
            );
          },
        ),
      ),
    );
  }
}
