import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/registeration_provider.dart';
import '../auth/verify_otp_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  /// Handles OTP sending process with validation and error handling
  Future<void> _sendOTP(BuildContext context) async {
    // Unfocus to dismiss keyboard
    _phoneFocusNode.unfocus();

    final authProvider = context.read<AuthProvider>();
    final phoneNumber = _phoneController.text.trim();

    // Input validation
    if (phoneNumber.isEmpty) {
      _showSnackbar(context, 'Please enter a phone number', Colors.red);
      return;
    }

    if (!authProvider.isValidPhoneNumber(phoneNumber)) {
      _showSnackbar(context, 'Please enter a valid phone number', Colors.red);
      return;
    }

    // Construct full phone number with country code
    final fullPhoneNumber = '${authProvider.countryCode}$phoneNumber';

    try {
      final result = await authProvider.sendOtp(fullPhoneNumber);

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackbar(context, 'OTP sent successfully', Colors.green);

        // Brief delay for better UX before navigation
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyOtpScreen(phoneNumber: fullPhoneNumber),
            ),
          );
        }
      } else {
        // Show error message from API response
        final errorMessage = result['message'] ?? 'Failed to send OTP';
        _showSnackbar(context, errorMessage, Colors.red);
      }
    } catch (error) {
      // Handle unexpected errors
      if (mounted) {
        _showSnackbar(context, 'An error occurred. Please try again.', Colors.red);
      }
    }
  }

  /// Displays snackbar with consistent styling
  void _showSnackbar(BuildContext context, String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens country picker dialog for phone code selection
  void _showCountryPicker(BuildContext context, AuthProvider authProvider) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (country) {
        authProvider.setCountry(
          "+${country.phoneCode}",
          country.flagEmoji,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset('assets/images/arrow.png', width: 25, height: 25),
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
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            // Header section
                            const Text(
                              "Join us via phone number",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontFamily: "UberMove",
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "We'll text a code to verify your phone",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontFamily: "UberMove",
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Phone number input field
                            SizedBox(
                              width: 300,
                              height: 45,
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
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
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.black, width: 2),
                                  ),
                                  prefixIcon: GestureDetector(
                                    onTap: () => _showCountryPicker(context, authProvider),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10.5),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 14),
                                          // Country flag display
                                          Text(
                                              authProvider.flagEmoji,
                                              style: const TextStyle(fontSize: 22)
                                          ),
                                          const SizedBox(width: 5),
                                          // Country code display
                                          Text(
                                            authProvider.countryCode,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold
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

                      // Next button section
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)
                              ),
                            ),
                            onPressed: authProvider.isLoading ? null : () => _sendOTP(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 15.0),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : const Text(
                                "Next",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: "UberMove"
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