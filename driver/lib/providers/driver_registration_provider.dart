// providers/driver_registration_provider.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../models/registration_data.dart';
import '../screens/SubmissionUnderReviewPage.dart';
import '../services/driver_registration_api.dart';

class RegistrationProvider with ChangeNotifier {
  RegistrationData _data = RegistrationData();
  int _currentStep = 0;
  final PageController _pageController = PageController();

  RegistrationData get data => _data;

  int get currentStep => _currentStep;

  PageController get pageController => _pageController;

  // -------------------------------
  // Stepper control
  // -------------------------------
  void setCurrentStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // -------------------------------
  // Update registration data fields
  // -------------------------------
  void updateData(RegistrationData newData) {
    _data = newData;
    notifyListeners();
  }

  void updateFirstName(String value) {
    _data.firstName = value;
    notifyListeners();
  }

  void updateLastName(String value) {
    _data.lastName = value;
    notifyListeners();
  }

  void updateDateOfBirth(DateTime value) {
    _data.dateOfBirth = value;
    notifyListeners();
  }

  void updateEmail(String value) {
    _data.email = value;
    notifyListeners();
  }

  void updateProfilePhoto(File value) {
    _data.profilePhoto = value;
    notifyListeners();
  }

  void updateCnicNumber(String value) {
    _data.cnicNumber = value;
    notifyListeners();
  }

  void updateCnicFront(File value) {
    _data.cnicFront = value;
    notifyListeners();
  }

  void updateCnicBack(File value) {
    _data.cnicBack = value;
    notifyListeners();
  }

  void updateLicenseNumber(String value) {
    _data.licenseNumber = value;
    notifyListeners();
  }

  void updateLicenseExpiryDate(DateTime value) {
    _data.licenseExpiryDate = value;
    notifyListeners();
  }

  void updateLicensePhoto(File value) {
    _data.licensePhoto = value;
    notifyListeners();
  }

  void updateVehicleType(String value) {
    _data.vehicleType = value;
    notifyListeners();
  }

  void updateCompanyModel(String value) {
    _data.companyModel = value;
    notifyListeners();
  }

  void updateVehicleColor(String value) {
    _data.vehicleColor = value;
    notifyListeners();
  }

  void updateNumberPlate(String value) {
    _data.numberPlate = value;
    notifyListeners();
  }

  void updateManufacturingYear(String value) {
    _data.manufacturingYear = value;
    notifyListeners();
  }

  void updateVehiclePhoto(File value) {
    _data.vehiclePhoto = value;
    notifyListeners();
  }

  void updateRegistrationFront(File value) {
    _data.registrationFront = value;
    notifyListeners();
  }

  void updateRegistrationBack(File value) {
    _data.registrationBack = value;
    notifyListeners();
  }

  // Update uploaded file URLs
  void updateProfilePhotoUrl(String value) {
    _data.profilePhotoUrl = value;
    notifyListeners();
  }

  void updateCnicFrontUrl(String value) {
    _data.cnicFrontUrl = value;
    notifyListeners();
  }

  void updateCnicBackUrl(String value) {
    _data.cnicBackUrl = value;
    notifyListeners();
  }

  void updateLicensePhotoUrl(String value) {
    _data.licensePhotoUrl = value;
    notifyListeners();
  }

  void updateVehiclePhotoUrl(String value) {
    _data.vehiclePhotoUrl = value;
    notifyListeners();
  }

  void updateRegistrationFrontUrl(String value) {
    _data.registrationFrontUrl = value;
    notifyListeners();
  }

  void updateRegistrationBackUrl(String value) {
    _data.registrationBackUrl = value;
    notifyListeners();
  }

  // -------------------------------
  // Registration Submission Logic
  // -------------------------------
  Future<void> submitRegistration(
      BuildContext context,
      GlobalKey<FormState> formKey,
      RegistrationProvider provider,
      ) async {
    // 0) Validate form fields
    if (!formKey.currentState!.validate()) {
      return; // stop if form validation fails
    }

    // Save the form state (triggers onSaved in each TextFormField)
    formKey.currentState!.save();

    final _data = provider.data;

    // 1) Check internet
    if (!await DriverRegistrationApi.checkInternetConnection()) {
      if (!context.mounted) return;
      _showDialog(
        context,
        'No Internet Connection',
        'Please check your internet connection and try again.',
      );
      return;
    }

    // 2) Validate required fields
    final missingFields = _data.getMissingRequiredFields();
    if (missingFields.isNotEmpty) {
      if (!context.mounted) return;
      _showDialog(
        context,
        'Missing Information',
        'Please fill in:\n${missingFields.join(', ')}',
      );
      return;
    }

    // 2b) Validate required images
    final missingImages = _data.getMissingImageFiles();
    if (missingImages.isNotEmpty) {
      if (!context.mounted) return;
      _showDialog(
        context,
        'Missing Images',
        'Please capture:\n${missingImages.join(', ')}',
      );
      return;
    }

    // 3) Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text('Uploading images and submitting registration...'),
            ),
          ],
        ),
      ),
    );

    try {
      // 4) Duplicate checks
      await DriverRegistrationApi.checkForDuplicates(_data);

      // 5) Upload images
      await DriverRegistrationApi.uploadImages(_data);
      if (!_data.areAllImagesUploaded()) {
        await SchedulerBinding.instance.endOfFrame;
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        _showDialog(
          context,
          'Upload Error',
          'Failed to upload some images. Please try again.',
        );
        return;
      }

      // 6) Submit registration
      final response = await DriverRegistrationApi.submitRegistration(_data);

      await SchedulerBinding.instance.endOfFrame;
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // 7) Handle response
      if (response.statusCode == 200) {
        // Build status map for multi-role
        final statusMap = <String, String>{
          'driver': 'pending', // driver always pending immediately after registration
          'mechanic': _data.isMechanic ? 'pending' : 'not_registered', // only if mechanic role
        };

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationStatusScreen(statuses: statusMap),
          ),
              (Route<dynamic> route) => false,
        );

      } else if (response.statusCode == 409) {
        final errorData = json.decode(response.body);
        _showDialog(
          context,
          'Duplicate Entry',
          errorData['message'] ?? 'Information already registered',
        );
      } else {
        _showDialog(
          context,
          'Error',
          'Registration failed: ${response.statusCode}',
        );
      }

    } on SocketException {
      await SchedulerBinding.instance.endOfFrame;
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showDialog(context, 'Network Error', 'Could not connect to the server.');
    } on http.ClientException catch (e) {
      await SchedulerBinding.instance.endOfFrame;
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showDialog(context, 'Connection Error', 'Failed to connect: ${e.message}');
    } catch (e) {
      await SchedulerBinding.instance.endOfFrame;
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showDialog(context, 'Error', 'Registration failed: $e');
    }
  }


  // Helper dialog method
  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // prevents black screen behind
      builder: (dialogContext) =>
          AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                  // This only closes the error dialog,
                  // user stays on the registration screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}