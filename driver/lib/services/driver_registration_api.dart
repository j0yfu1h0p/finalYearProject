// driver_registration_api.dart

import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../models/registration_data.dart';
import '../services/auth_service.dart';

// Constants for API configuration
class ApiConstants {
  // Base URL for the server
  static const String baseUrl = 'https://smiling-sparrow-proper.ngrok-free.app';

  // Endpoints
  static const String checkCnicEndpoint = '/api/driver/check-cnic';
  static const String checkLicenseEndpoint = '/api/driver/check-license';
  static const String checkPlateEndpoint = '/api/driver/check-plate';
  static const String registerEndpoint = '/api/driver/register';

  // Image upload configuration
  static const String imgBbApiKey = '5901839607895f07bae1636c9ff8fb4e';
  static const String imgBbUploadUrl = 'https://api.imgbb.com/1/upload';

  // Allowed image file extensions and size limit
  static const double maxFileSizeMB = 32.0;
  static const List<String> allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'
  ];
}



// Driver registration API implementation
class DriverRegistrationApi {
  // Check if internet connection is available
  static Future<bool> checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Check for duplicates (CNIC, license, or plate number)
  static Future<void> checkForDuplicates(RegistrationData data) async {
    try {
      // Check CNIC
      final cnicCheck = await makeAuthenticatedRequest(
        '${ApiConstants.baseUrl}${ApiConstants.checkCnicEndpoint}?cnic=${data.cnicNumber}',
      );
      if (cnicCheck.statusCode == 200 && json.decode(cnicCheck.body)['exists']) {
        throw 'CNIC number already registered';
      }

      // Check license
      final licenseCheck = await makeAuthenticatedRequest(
        '${ApiConstants.baseUrl}${ApiConstants.checkLicenseEndpoint}?license=${data.licenseNumber}',
      );
      if (licenseCheck.statusCode == 200 && json.decode(licenseCheck.body)['exists']) {
        throw 'License number already registered';
      }

      // Check plate number
      final plateCheck = await makeAuthenticatedRequest(
        '${ApiConstants.baseUrl}${ApiConstants.checkPlateEndpoint}?plate=${data.numberPlate}',
      );
      if (plateCheck.statusCode == 200 && json.decode(plateCheck.body)['exists']) {
        throw 'Vehicle plate number already registered';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Upload images to ImgBB and store URLs
  static Future<void> uploadImages(RegistrationData data) async {
    Future<void> _uploadSingleImage(File? file, String urlFieldName) async {
      if (file != null && data.getUrlField(urlFieldName) == null) {
        try {
          String imageUrl = await uploadImage(file);
          data.setUrlField(urlFieldName, imageUrl);
        } catch (e) {
          throw Exception('Failed to upload $urlFieldName: $e');
        }
      }
    }

    await _uploadSingleImage(data.profilePhoto, 'profilePhotoUrl');
    await _uploadSingleImage(data.cnicFront, 'cnicFrontUrl');
    await _uploadSingleImage(data.cnicBack, 'cnicBackUrl');
    await _uploadSingleImage(data.licensePhoto, 'licensePhotoUrl');
    await _uploadSingleImage(data.vehiclePhoto, 'vehiclePhotoUrl');
    await _uploadSingleImage(data.registrationFront, 'registrationFrontUrl');
    await _uploadSingleImage(data.registrationBack, 'registrationBackUrl');
  }

  // Submit registration data to the server
  static Future<http.Response> submitRegistration(RegistrationData data) async {
    final requestBody = {
      'personal_info': {
        'first_name': data.firstName,
        'last_name': data.lastName,
        'date_of_birth': data.dateOfBirth?.toIso8601String(),
        'email': data.email,
        'profile_photo_url': data.profilePhotoUrl,
      },
      'identification': {
        'cnic_number': data.cnicNumber,
        'cnic_front_url': data.cnicFrontUrl,
        'cnic_back_url': data.cnicBackUrl,
      },
      'license': {
        'license_number': data.licenseNumber,
        'license_photo_url': data.licensePhotoUrl,
        'expiry_date': data.licenseExpiryDate?.toIso8601String(),
      },
      'vehicles': [
        {
          'vehicle_type': data.vehicleType,
          'company_model': data.companyModel,
          'color': data.vehicleColor,
          'number_plate': data.numberPlate,
          'manufacturing_year': data.manufacturingYear,
          'vehicle_photo_url': data.vehiclePhotoUrl,
          'registration_front_url': data.registrationFrontUrl,
          'registration_back_url': data.registrationBackUrl,
        }
      ],
    };

    return await makeAuthenticatedRequest(
      '${ApiConstants.baseUrl}${ApiConstants.registerEndpoint}',
      body: requestBody,
    );
  }
}

// Image upload functions
Future<String> uploadImage(File imageFile) async {
  try {
    // Encode image to Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Prepare multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.imgBbUploadUrl}?key=${ApiConstants.imgBbApiKey}'),
    );
    request.fields['image'] = base64Image;
    request.fields['name'] = imageFile.path.split('/').last;

    // Send request and parse response
    var response = await request.send();
    if (response.statusCode == 200) {
      var respBody = await response.stream.bytesToString();
      var data = json.decode(respBody);
      if (data['success'] == true) {
        return data['data']['url'];
      } else {
        throw Exception('Upload failed: ${data['error']['message']}');
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Image upload failed: $e');
  }
}

// Validate image before upload
bool validateImage(File imageFile) {
  // Check file size (max 32MB)
  final fileSizeInBytes = imageFile.lengthSync();
  final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
  if (fileSizeInMB > ApiConstants.maxFileSizeMB) return false;

  // Check file extension
  final extension = imageFile.path.split('.').last.toLowerCase();
  return ApiConstants.allowedExtensions.contains(extension);
}

// Utility function for authenticated API requests
Future<http.Response> makeAuthenticatedRequest(String url, {Map<String, dynamic>? body}) async {
  final token = await Auth.getToken();
  if (token == null) throw Exception('No token found');

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  return await http.post(
    Uri.parse(url),
    headers: headers,
    body: jsonEncode(body ?? {}),
  );
}

// Error message handler for API responses
String getErrorMessage(int statusCode, Map<String, dynamic> responseData) {
  switch (statusCode) {
    case 400: return responseData['message'] ?? 'Invalid request';
    case 401: return responseData['message'] ?? 'Authentication failed';
    case 429: return responseData['message'] ?? 'Too many requests. Please try again later';
    case 500: return responseData['message'] ?? 'Server error. Please try again later';
    default: return responseData['message'] ?? 'Failed to complete the request';
  }
}
