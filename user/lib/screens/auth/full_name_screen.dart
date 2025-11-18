// full_name_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:user/screens/enable_location_screen.dart';
import '../../services/api_service.dart';

class FullNameScreen extends StatefulWidget {
  final String? phoneNumber;

  const FullNameScreen({Key? key, this.phoneNumber}) : super(key: key);

  @override
  _FullNameScreenState createState() => _FullNameScreenState();
}

class _FullNameScreenState extends State<FullNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // Application constants
  static const String appBarTitle = "MyAutoBridge";
  static const String welcomeTitle = "Welcome";
  static const String subtitle = "Please introduce yourself";
  static const String buttonText = "Next";
  static const String hintText = "Enter your full name";
  static const String errorInvalidName = "Please enter a valid full name (e.g., John Doe)";
  static const String errorMissingPhone = "Phone number is missing. Please restart registration.";
  static const String successMessage = "Registration complete!";
  static const String errorMessage = "Failed to submit full name. Please try again.";

  // Text styling constants
  static const TextStyle appBarTitleStyle = TextStyle(
    fontSize: 35,
    fontWeight: FontWeight.bold,
    fontFamily: "UberMove",
  );

  static const TextStyle welcomeTitleStyle = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.bold,
    fontFamily: "UberMove",
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 15,
    fontFamily: "UberMove",
  );

  static const TextStyle inputTextStyle = TextStyle(
    fontSize: 16,
    fontFamily: "UberMove",
  );

  // Layout constants
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(horizontal: 20.0);
  static const EdgeInsets buttonPadding = EdgeInsets.only(bottom: 20.0);
  static const double textFieldWidth = 300;
  static const double textFieldHeight = 40;
  static const double topSectionHeightFactor = 0.05;

  @override
  void initState() {
    super.initState();
    // Phone number validation is handled in submit method
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Validates that the full name contains at least two non-empty words
  bool _isValidFullName(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    final parts = trimmedName.split(RegExp(r'\s+'));
    return parts.length >= 2 && parts.every((part) => part.isNotEmpty);
  }

  // Displays an error message to the user
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Displays a success message to the user
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Handles the submission of the full name to the server
  Future<void> _submitFullName() async {
    final fullName = _nameController.text.trim();

    // Client-side validation
    if (fullName.isEmpty || !_isValidFullName(fullName)) {
      _showError(errorInvalidName);
      return;
    }

    // Security: Validate phone number exists before submission
    if (widget.phoneNumber == null || widget.phoneNumber!.isEmpty) {
      _showError(errorMissingPhone);
      return;
    }

    // Security: Sanitize input by trimming and limiting length
    final sanitizedName = fullName.substring(0, fullName.length.clamp(0, 100));

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.submitFullName(widget.phoneNumber!, sanitizedName);

      if (!mounted) return;

      if (result['success'] == true) {
        _showSuccess(successMessage);
        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => EnableLocationScreen()),
          );
        }
      } else {
        final message = result['message'] as String?;
        _showError(message ?? errorMessage);
      }
    } on TimeoutException {
      _showError('Request timed out. Please check your connection.');
    } on SocketException {
      _showError('No internet connection. Please try again.');
    } on FormatException {
      _showError('Invalid response from server.');
    } catch (e) {
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Application logo section
              Column(
                children: [
                  const SizedBox(height: 35),
                  Text(appBarTitle, style: appBarTitleStyle),
                  const SizedBox(height: 0),
                ],
              ),

              // User input form section
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * topSectionHeightFactor,
                  ).copyWith(
                    left: 20.0,
                    right: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(welcomeTitle, textAlign: TextAlign.center, style: welcomeTitleStyle),
                      const SizedBox(height: 10),
                      Text(subtitle, textAlign: TextAlign.center, style: subtitleStyle),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: textFieldWidth,
                        height: textFieldHeight + 10,
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.start,
                          textAlignVertical: TextAlignVertical.center,
                          cursorColor: Colors.black,
                          style: inputTextStyle,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: inputTextStyle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.black, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Submission button section
              Padding(
                padding: buttonPadding,
                child: SizedBox(
                  width: textFieldWidth,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitFullName,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
  }
}