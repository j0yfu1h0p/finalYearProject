import 'dart:convert';
import 'dart:io';
import 'package:driver/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import '../SubmissionUnderReviewPage.dart';

const List<String> SERVICES = [
  'car_lockout_service',
  'puncture_repair',
  'battery_jump_start',
  'fuel_delivery',
  'quote_after_inspection',
];

const Map<String, String> SERVICE_DISPLAY_NAMES = {
  'car_lockout_service': 'Car Lockout Service',
  'puncture_repair': 'Puncture Repair',
  'battery_jump_start': 'Battery Jump Start',
  'fuel_delivery': 'Fuel Delivery',
  'quote_after_inspection': 'Quote after inspection',
};

// ImgBB API configuration
const String IMGBB_API_KEY = '5901839607895f07bae1636c9ff8fb4e';
const String IMGBB_UPLOAD_URL = 'https://api.imgbb.com/1/upload';

class MechanicRegistrationScreen extends StatefulWidget {
  const MechanicRegistrationScreen({Key? key}) : super(key: key);

  @override
  _MechanicRegistrationScreenState createState() =>
      _MechanicRegistrationScreenState();
}

class _MechanicRegistrationScreenState
    extends State<MechanicRegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _personNameController = TextEditingController();
  final PageController _pageController = PageController();

  String? _personalPhotoPath;
  String? _workshopPhotoPath;
  String? _registrationCertificatePath;
  String? _introductionVideoPath;
  String? _cnicPhotoPath;

  // Store ImgBB URLs after upload
  String? _personalPhotoUrl;
  String? _workshopPhotoUrl;
  String? _registrationCertificateUrl;
  String? _introductionVideoUrl;
  String? _cnicPhotoUrl;

  Set<String> _selectedServices = {};
  int _currentStep = 0;
  List<String> stepTitles = ['Basic Info', 'Media', 'Services', 'Location'];
  bool _isGettingLocation = false;
  bool _isSubmitting = false;
  bool _isUploadingMedia = false;
  int _currentUploadIndex = 0;
  int _totalUploads = 0;
  String _currentUploadName = '';

  // Dio upload progress variables
  double _uploadProgress = 0.0;
  String _totalSize = '0 MB';

  // Image picker instance
  final ImagePicker _imagePicker = ImagePicker();

  // Dio instance
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emergencyContactController.dispose();
    _locationController.dispose();
    _shopNameController.dispose();
    _personNameController.dispose();
    _pageController.dispose();
    _dio.close();
    super.dispose();
  }

  // Function to upload image to ImgBB using Dio
  Future<Map<String, dynamic>?> uploadImageToImgBB(
    File imageFile,
    String fileName,
  ) async {
    try {
      // Convert file to base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Create form data
      FormData formData = FormData.fromMap({
        'image': base64Image,
        'name': fileName,
      });

      // Create Dio request with progress tracking
      var response = await _dio.post(
        '$IMGBB_UPLOAD_URL?expiration=15552000&key=$IMGBB_API_KEY',
        data: formData,
        onSendProgress: (int sent, int total) {
          if (total != -1) {
            setState(() {
              _uploadProgress = sent / total;
              _totalSize = '${(total / (1024 * 1024)).toStringAsFixed(2)} MB';
            });
          }
        },
      );

      var jsonResponse = response.data;

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return jsonResponse;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Function to upload all media files to ImgBB
  Future<bool> uploadAllMedia() async {
    setState(() {
      _isUploadingMedia = true;
      _currentUploadIndex = 0;
      _totalUploads = 0;
      _uploadProgress = 0.0;
      _totalSize = '0 MB';

      // Count total uploads
      if (_personalPhotoPath != null) _totalUploads++;
      if (_cnicPhotoPath != null) _totalUploads++;
      if (_workshopPhotoPath != null) _totalUploads++;
      if (_registrationCertificatePath != null) _totalUploads++;
    });

    try {
      // Upload personal photo
      if (_personalPhotoPath != null) {
        setState(() {
          _currentUploadIndex++;
          _currentUploadName = 'Personal Photo';
        });

        File file = File(_personalPhotoPath!);
        var response = await uploadImageToImgBB(
          file,
          'personal_photo_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (response != null) {
          _personalPhotoUrl = response['data']['url'];
        } else {
          throw Exception('Failed to upload personal photo');
        }
      }

      // Upload CNIC photo
      if (_cnicPhotoPath != null) {
        setState(() {
          _currentUploadIndex++;
          _currentUploadName = 'CNIC Photo';
        });

        File file = File(_cnicPhotoPath!);
        var response = await uploadImageToImgBB(
          file,
          'cnic_photo_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (response != null) {
          _cnicPhotoUrl = response['data']['url'];
        } else {
          throw Exception('Failed to upload CNIC photo');
        }
      }

      // Upload workshop photo
      if (_workshopPhotoPath != null) {
        setState(() {
          _currentUploadIndex++;
          _currentUploadName = 'Workshop Photo';
        });

        File file = File(_workshopPhotoPath!);
        var response = await uploadImageToImgBB(
          file,
          'workshop_photo_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (response != null) {
          _workshopPhotoUrl = response['data']['url'];
        } else {
          throw Exception('Failed to upload workshop photo');
        }
      }

      // Upload registration certificate
      if (_registrationCertificatePath != null) {
        setState(() {
          _currentUploadIndex++;
          _currentUploadName = 'Registration Certificate';
        });

        File file = File(_registrationCertificatePath!);
        var response = await uploadImageToImgBB(
          file,
          'certificate_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (response != null) {
          _registrationCertificateUrl = response['data']['url'];
        } else {
          throw Exception('Failed to upload certificate');
        }
      }

      // Upload introduction video (as image - ImgBB doesn't support videos directly)
      if (_introductionVideoPath != null) {
        // For videos, you might want to use a different service or handle differently
        // For now, we'll skip video upload to ImgBB
      }

      return true;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading media: $e')));
      return false;
    } finally {
      setState(() {
        _isUploadingMedia = false;
        _currentUploadIndex = 0;
        _totalUploads = 0;
        _currentUploadName = '';
        _uploadProgress = 0.0;
        _totalSize = '0 MB';
      });
    }
  }

  void nextStep() {
    if (_currentStep < 3 && _validateCurrentStep()) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mechanic Profile Registration',
          style: TextStyle(fontFamily: "UberMove"),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentStep + 1}/4',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            height: 4,
            color: Colors.grey[200],
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: Colors.transparent,
              color: Colors.green,
              minHeight: 4,
            ),
          ),

          // Step indicators
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (index) {
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index <= _currentStep
                            ? (index == _currentStep
                                  ? Colors.green
                                  : Colors.black)
                            : Colors.grey[300],
                        border: Border.all(
                          color: index == _currentStep
                              ? Colors.green
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index <= _currentStep
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stepTitles[index],
                      style: TextStyle(
                        color: index == _currentStep
                            ? Colors.black
                            : Colors.grey[600],
                        fontWeight: index == _currentStep
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: "UberMove",
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          // Form content
          Expanded(
            child: Stack(
              children: [
                PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBasicInfoStep(),
                    _buildMediaStep(),
                    _buildServicesStep(),
                    _buildLocationStep(),
                  ],
                ),

                // Upload progress overlay
                if (_isUploadingMedia)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Uploading Media...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$_currentUploadIndex/$_totalUploads',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _currentUploadName,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          // Upload progress with MB
                          Text(
                            '$_totalSize',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: (_isSubmitting || _isUploadingMedia)
                    ? null
                    : previousStep,
                child: const Text(
                  'Previous',
                  style: TextStyle(fontFamily: "UberMove"),
                ),
              )
            else
              const SizedBox(width: 80),
            if (_currentStep < 3)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: (_isSubmitting || _isUploadingMedia)
                    ? null
                    : () {
                        if (_validateCurrentStep()) {
                          nextStep();
                        }
                      },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: "UberMove",
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                  ],
                ),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: (_isSubmitting || _isUploadingMedia)
                    ? null
                    : () async {
                        if (_validateCurrentStep()) {
                          await _submitForm();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SplashScreen()
                            ),
                            (route) => false,
                          );
                        }
                      },
                child: (_isSubmitting || _isUploadingMedia)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Registration',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: "UberMove",
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Your Full Name', Icons.person),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _personNameController,
              hintText: 'Enter your full name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
              enabled: !_isSubmitting && !_isUploadingMedia,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Shop Name', Icons.store),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _shopNameController,
              hintText: 'Enter your shop/garage name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your shop name';
                }
                return null;
              },
              enabled: !_isSubmitting && !_isUploadingMedia,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Emergency Contact', Icons.emergency),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _emergencyContactController,
              hintText: 'Enter emergency contact number',
              keyboardType: TextInputType.phone,
              prefixText: '+92 ',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter emergency contact';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
              enabled: !_isSubmitting && !_isUploadingMedia,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Personal Photo', Icons.person),
          const SizedBox(height: 12),
          Center(
            child: _buildImageUploadCard(
              title: 'Personal photo',
              subtitle: 'This will be shown to customers',
              imagePath: _personalPhotoPath,
              onTap: (_isSubmitting || _isUploadingMedia)
                  ? null
                  : () => _showImageSourceDialog('personal'),
              icon: Icons.camera_alt,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('CNIC Photo', Icons.badge),
          const SizedBox(height: 12),
          Center(
            child: _buildImageUploadCard(
              title: 'CNIC photo',
              subtitle: 'Upload a clear picture of your CNIC',
              imagePath: _cnicPhotoPath,
              onTap: (_isSubmitting || _isUploadingMedia)
                  ? null
                  : () => _showImageSourceDialog('cnic'),
              icon: Icons.credit_card,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Workshop Photo', Icons.build),
          const SizedBox(height: 12),
          Center(
            child: _buildImageUploadCard(
              title: 'Workshop photo',
              subtitle: 'Show your professional workspace',
              imagePath: _workshopPhotoPath,
              onTap: (_isSubmitting || _isUploadingMedia)
                  ? null
                  : () => _showImageSourceDialog('workshop'),
              icon: Icons.business,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Introduction Video', Icons.video_camera_back),
          const SizedBox(height: 12),
          Center(
            child: _buildVideoUploadCard(
              title: 'Introduction video',
              subtitle: 'Record a short introduction (30-60 sec)',
              videoPath: _introductionVideoPath,
              onTap: (_isSubmitting || _isUploadingMedia)
                  ? null
                  : () => _showVideoSourceDialog(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Registration Certificate', Icons.verified),
          const SizedBox(height: 12),
          Center(
            child: _buildDocumentUploadCard(
              title: 'Registration certificate',
              subtitle: 'Business registration, license or certificate',
              filePath: _registrationCertificatePath,
              onTap: (_isSubmitting || _isUploadingMedia)
                  ? null
                  : () => _showDocumentSourceDialog(),
              icon: Icons.description,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Services Offered', Icons.engineering),
          const SizedBox(height: 12),
          _buildServicesSelection(),
          const SizedBox(height: 16),
          Text(
            'Select all services you offer',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Workshop Location', Icons.location_on),
          const SizedBox(height: 12),
          _buildLocationField(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Location Access Note',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Please be at your shop location when getting your location. This helps us verify your workshop address and show accurate location to customers.',
                  style: TextStyle(color: Colors.blue[700], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green[600], size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
    String? prefixText,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        readOnly: readOnly,
        enabled: enabled,
        style: TextStyle(color: Colors.grey[800], fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          suffixIcon: suffixIcon,
          prefixText: prefixText,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildServicesSelection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: SERVICES.map((service) {
          return CheckboxListTile(
            title: Text(SERVICE_DISPLAY_NAMES[service] ?? service), // Use display name
            value: _selectedServices.contains(service),
            onChanged: (_isSubmitting || _isUploadingMedia)
                ? null
                : (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedServices.add(service);
                } else {
                  _selectedServices.remove(service);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      children: [
        _buildTextFormField(
          controller: _locationController,
          hintText: 'Enter workshop address',
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter workshop location';
            }
            return null;
          },
          enabled: !_isSubmitting && !_isUploadingMedia,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: (_isSubmitting || _isUploadingMedia)
              ? null
              : _getCurrentLocation,
          icon: _isGettingLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.my_location),
          label: const Text('Use Current Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    String? imagePath,
    required VoidCallback? onTap,
    required IconData icon,
  }) {
    return Opacity(
      opacity: (_isSubmitting || _isUploadingMedia) ? 0.6 : 1.0,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: imagePath != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(imagePath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Photo uploaded',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to change',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 48, color: Colors.green[600]),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    String? filePath,
    required VoidCallback? onTap,
    required IconData icon,
  }) {
    return Opacity(
      opacity: (_isSubmitting || _isUploadingMedia) ? 0.6 : 1.0,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: filePath != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description,
                          color: Colors.green[600],
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Document uploaded',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to change',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 48, color: Colors.green[600]),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoUploadCard({
    required String title,
    required String subtitle,
    String? videoPath,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: (_isSubmitting || _isUploadingMedia) ? 0.6 : 1.0,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: videoPath != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.videocam,
                          color: Colors.green[600],
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Video uploaded',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to change',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 48, color: Colors.green[600]),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog(String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, type);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVideoSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Video Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDocumentSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Document Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Choose File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument(false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          if (type == 'personal') {
            _personalPhotoPath = image.path;
          } else if (type == 'workshop') {
            _workshopPhotoPath = image.path;
          } else if (type == 'cnic') {
            _cnicPhotoPath = image.path;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(source: source);
      if (video != null) {
        setState(() {
          _introductionVideoPath = video.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking video: $e')));
    }
  }

  Future<void> _pickDocument(bool isCamera) async {
    try {
      if (isCamera) {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
        );
        if (image != null) {
          setState(() {
            _registrationCertificatePath = image.path;
          });
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        );

        if (result != null && result.files.single.path != null) {
          setState(() {
            _registrationCertificatePath = result.files.single.path!;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        String address =
            '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}';

        setState(() {
          _locationController.text = address;
          _isGettingLocation = false;
        });
      } else {
        setState(() {
          _isGettingLocation = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_personNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your name')),
          );
          return false;
        }
        if (_shopNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your shop name')),
          );
          return false;
        }
        if (_emergencyContactController.text.isEmpty ||
            _emergencyContactController.text.length < 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid emergency contact'),
            ),
          );
          return false;
        }
        return true;
      case 1:
        if (_personalPhotoPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload your personal photo')),
          );
          return false;
        }
        if (_cnicPhotoPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload your CNIC photo')),
          );
          return false;
        }
        if (_workshopPhotoPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload your workshop photo')),
          );
          return false;
        }
        return true;
      case 2:
        if (_selectedServices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one service')),
          );
          return false;
        }
        return true;
      case 3:
        if (_locationController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your workshop location'),
            ),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitForm() async {
    if (!_validateCurrentStep()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // First upload all media to ImgBB
      bool mediaUploadSuccess = await uploadAllMedia();
      if (!mediaUploadSuccess) {
        throw Exception('Failed to upload media files');
      }

      // Get current location coordinates
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Prepare the JSON data
      Map<String, dynamic> requestData = {
        'personName': _personNameController.text,
        'shopName': _shopNameController.text,
        'emergencyContact': '+92${_emergencyContactController.text}',
        'phoneNumber': '+92${_emergencyContactController.text}',
        'address': _locationController.text,
        'servicesOffered': _selectedServices.toList(),
        'location': {
          'type': 'Point',
          'coordinates': [position.longitude, position.latitude],
        },
      };

      // Add ImgBB URLs if they exist
      if (_personalPhotoUrl != null)
        requestData['personalPhotoUrl'] = _personalPhotoUrl!;
      if (_cnicPhotoUrl != null) requestData['cnicPhotoUrl'] = _cnicPhotoUrl!;
      if (_workshopPhotoUrl != null)
        requestData['workshopPhotoUrl'] = _workshopPhotoUrl!;
      if (_registrationCertificateUrl != null)
        requestData['registrationCertificateUrl'] =
            _registrationCertificateUrl!;
      if (_introductionVideoUrl != null)
        requestData['introductionVideoUrl'] = _introductionVideoUrl!;

      // Get auth token
      final token = await Auth.getToken();
      if (token == null) throw Exception('No token found');

      // Send POST request with JSON body
      final response = await _dio.post(
        'https://smiling-sparrow-proper.ngrok-free.app/api/mechanic/profile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: requestData,
      );

      final responseData = response.data;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration submitted successfully!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting form: $e')));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
