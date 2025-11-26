import 'package:admin/auth_service.dart';
import 'package:admin/screens/login.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Represents driver entity with comprehensive profile and verification data
/// Includes personal information, identification documents, and vehicle details
class Driver {
  final String id;
  final String phoneNumber;
  final String cnicNumber;
  final String cnicFrontUrl;
  final String cnicBackUrl;
  final bool cnicVerified;
  final String licenseNumber;
  final String licensePhotoUrl;
  final DateTime? licenseExpiry; // Make nullable
  final bool licenseVerified;
  final String firstName;
  final String lastName;
  final DateTime? dob; // Make nullable
  final String email;
  final String profilePhotoUrl;
  String registrationStatus;
  final double rating;
  final int ratingCount;
  final List<Vehicle> vehicles;

  Driver.fromJson(Map<String, dynamic> json)
    : id = json['_id']?.toString() ?? '',
      phoneNumber = json['phoneNumber']?.toString() ?? '',
      cnicNumber = json['identification']?['cnic_number']?.toString() ?? '',
      cnicFrontUrl =
          json['identification']?['cnic_front_url']?.toString() ?? '',
      cnicBackUrl = json['identification']?['cnic_back_url']?.toString() ?? '',
      cnicVerified = json['identification']?['verified'] ?? false,
      licenseNumber = json['license']?['license_number']?.toString() ?? '',
      licensePhotoUrl = json['license']?['license_photo_url']?.toString() ?? '',
      licenseExpiry = json['license']?['expiry_date'] != null
          ? DateTime.tryParse(json['license']?['expiry_date']?.toString() ?? '')
          : null,
      licenseVerified = json['license']?['verified'] ?? false,
      firstName = json['personal_info']?['first_name']?.toString() ?? '',
      lastName = json['personal_info']?['last_name']?.toString() ?? '',
      dob = json['personal_info']?['date_of_birth'] != null
          ? DateTime.tryParse(
              json['personal_info']?['date_of_birth']?.toString() ?? '',
            )
          : null,
      email = json['personal_info']?['email']?.toString() ?? '',
      profilePhotoUrl =
          json['personal_info']?['profile_photo_url']?.toString() ?? '',
      registrationStatus =
          json['personal_info']?['registration_status']?.toString() ??
          'pending',
      rating = json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating']?.toString() ?? '') ?? 0.0,
      ratingCount = json['ratingCount'] is num
          ? (json['ratingCount'] as num).toInt()
          : int.tryParse(json['ratingCount']?.toString() ?? '') ?? 0,
      vehicles = (json['vehicles'] as List? ?? [])
          .map((v) => Vehicle.fromJson(v))
          .toList();
}

/// Represents vehicle information associated with a driver
/// Contains vehicle specifications and registration documents

class Vehicle {
  final String type;
  final String model;
  final String color;
  final String plate;
  final String year;
  final String photoUrl;
  final String regFrontUrl;
  final String regBackUrl;

  Vehicle.fromJson(Map<String, dynamic> json)
    : type = json['vehicle_type']?.toString() ?? '',
      model = json['company_model']?.toString() ?? '',
      color = json['color']?.toString() ?? '',
      plate = json['number_plate']?.toString() ?? '',
      year = json['manufacturing_year']?.toString() ?? '',
      photoUrl = json['vehicle_photo_url']?.toString() ?? '',
      regFrontUrl = json['registration_front_url']?.toString() ?? '',
      regBackUrl = json['registration_back_url']?.toString() ?? '';
}

/// Administrative service class for driver management operations
/// Handles API communication for driver details, approval, and rejection
class AdminService {
  final String _baseUrl =
      'https://smiling-sparrow-proper.ngrok-free.app/api/admin';
  final AuthService _authService = AuthService();

  /// Retrieves detailed driver information from the API
  /// Throws exception on network errors or invalid responses
  Future<Driver> getDriverDetails(String driverId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/drivers/$driverId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['driver'] == null) {
          throw Exception('Driver data not found in response');
        }
        return Driver.fromJson(data['driver']);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access');
      } else if (response.statusCode == 404) {
        throw Exception('Driver not found');
      } else {
        throw Exception(
          'Failed to load driver details: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Handle JSON parsing errors specifically
      if (e is FormatException) {
        throw Exception('Invalid response format from server');
      }
      rethrow;
    }
  }

  /// Approves driver registration after verification
  /// Updates driver status to approved in the system
  Future<void> approveDriver(String driverId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/drivers/$driverId/approve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else if (response.statusCode != 200) {
      throw Exception('Failed to approve driver: ${response.statusCode}');
    }
  }

  /// Rejects driver registration with proper status update
  /// Prevents driver from accessing platform services
  Future<void> rejectDriver(String driverId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/drivers/$driverId/reject'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else if (response.statusCode != 200) {
      throw Exception('Failed to reject driver: ${response.statusCode}');
    }
  }
}

/// Detailed view screen for driver verification and management
/// Provides comprehensive driver information with approval/rejection capabilities
class DriverDetailScreen extends StatefulWidget {
  final String driverId;

  const DriverDetailScreen({super.key, required this.driverId});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  Driver? driver;
  bool isLoading = true;

  /// White theme color scheme using same values as original but with white theme
  static const Color _backgroundColor = Colors.white;
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textPrimary = Colors.black;
  static const Color _textSecondary = Colors.grey;
  static const Color _accentColor = Colors.green;
  static const Color _errorColor = Colors.red;
  static const Color _warningColor = Colors.orange;

  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchDriverDetails();
  }

  /// Handles unauthorized access by clearing tokens and redirecting to login
  void _handleUnauthorized() {
    _authService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );

    SnackBarUtil.showError(context, 'Session expired. Please login again.');
  }

  /// Fetches driver details from API with authentication and error handling
  /// Updates UI state based on API response success or failure
  Future<void> _fetchDriverDetails() async {
    try {
      final fetchedDriver = await _adminService.getDriverDetails(
        widget.driverId,
      );
      setState(() {
        driver = fetchedDriver;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (e.toString().contains('Unauthorized')) {
        _handleUnauthorized();
      } else {
        _showErrorDialog('Failed to load driver details: $e');
      }
    }
  }

  /// Displays error dialog with descriptive message and user action options
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Error', style: TextStyle(color: _textPrimary)),
        content: Text(message, style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  /// Shows confirmation dialog for critical actions like approval/rejection
  /// Ensures user intent before executing irreversible operations
  void _showConfirmationDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(title, style: const TextStyle(color: _textPrimary)),
        content: Text(message, style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: Text('Confirm', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  /// Processes driver approval with haptic feedback and status updates
  /// Handles API communication errors and provides user feedback
  void _approveDriver() {
    _showConfirmationDialog(
      'Approve Driver',
      'Are you sure you want to approve this driver?',
      () async {
        try {
          HapticFeedback.lightImpact();
          await _adminService.approveDriver(widget.driverId);
          setState(() {
            driver?.registrationStatus = 'approved';
          });
          SnackBarUtil.showSuccess(context, 'Driver approved successfully');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) {
            _handleUnauthorized();
          } else {
            _showErrorDialog('Failed to approve driver: $e');
          }
        }
      },
    );
  }

  /// Processes driver rejection with appropriate status change
  /// Provides haptic feedback and error handling for API failures
  void _rejectDriver() {
    _showConfirmationDialog(
      'Reject Driver',
      'Are you sure you want to reject this driver?',
      () async {
        try {
          HapticFeedback.lightImpact();
          await _adminService.rejectDriver(widget.driverId);
          setState(() {
            driver?.registrationStatus = 'rejected';
          });
          SnackBarUtil.showError(context, 'Driver rejected');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) {
            _handleUnauthorized();
          } else {
            _showErrorDialog('Failed to reject driver: $e');
          }
        }
      },
    );
  }

  /// Opens document images in external viewer or browser
  /// Handles URL launching errors and provides user feedback
  Future<void> _openImage(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      SnackBarUtil.showError(context, 'Failed to open image');
      return;
    }
    await launchUrl(uri);
  }

  /// Constructs standardized information row with label-value pair
  /// Supports verification status indicator for verified documents
  Widget _buildInfoRow(String label, String value, {bool isVerified = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontFamily: 'UberMove',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontFamily: 'UberMove',
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 16, color: _accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRatingCard() {
    final double average = driver?.rating ?? 0;
    final int count = driver?.ratingCount ?? 0;
    final bool hasReviews = count > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rate_rounded,
                color: _accentColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Rating',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontFamily: 'UberMove',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasReviews ? average.toStringAsFixed(1) : '--',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        hasReviews
                            ? '$count review${count == 1 ? '' : 's'}'
                            : 'No reviews yet',
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                          fontFamily: 'UberMove',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasReviews
                        ? 'Latest rating reflects completed rides and dispute outcomes.'
                        : 'Once riders submit reviews, their scores will appear here.',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontFamily: 'UberMove',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates interactive document card with image preview
  /// Supports tap-to-open functionality for document inspection
  Widget _buildDocumentCard(String title, String imageUrl) {
    return GestureDetector(
      onTap: () => _openImage(imageUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'UberMove',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300],
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: _errorColor,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Failed to load image',
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_outlined,
                              color: _textSecondary,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No image available',
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds organized content section with title and child widgets
  /// Provides consistent styling for different information categories
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'UberMove',
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Generates status badge with color-coded visual indicators
  /// Displays current registration status with appropriate styling
  Widget _buildStatusBadge() {
    final status = (driver?.registrationStatus ?? 'pending').toLowerCase();
    late Color color;
    late String text;

    switch (status) {
      case 'approved':
        color = _accentColor;
        text = 'Approved';
        break;
      case 'rejected':
        color = _errorColor;
        text = 'Rejected';
        break;
      default:
        color = _warningColor;
        text = 'Pending Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontFamily: 'UberMove',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(_accentColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading driver details...',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 16,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final vehicleList = driver?.vehicles ?? <Vehicle>[];

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text(
          'Driver Details',
          style: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: _cardColor,
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.check_circle, color: _accentColor),
                        title: const Text(
                          'Approve Driver',
                          style: TextStyle(
                            color: _textPrimary,
                            fontFamily: 'UberMove',
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _approveDriver();
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.pending, color: _warningColor),
                        title: const Text(
                          'Mark as Pending',
                          style: TextStyle(
                            color: _textPrimary,
                            fontFamily: 'UberMove',
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            driver?.registrationStatus = 'pending';
                          });
                          SnackBarUtil.showWarning(
                            context,
                            'Driver marked as pending',
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.cancel, color: _errorColor),
                        title: const Text(
                          'Reject Application',
                          style: TextStyle(
                            color: _textPrimary,
                            fontFamily: 'UberMove',
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _rejectDriver();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Profile Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          driver?.profilePhotoUrl.isNotEmpty == true
                          ? NetworkImage(driver!.profilePhotoUrl)
                          : null,
                      child: driver?.profilePhotoUrl.isEmpty == true
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: _textSecondary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${driver?.firstName} ${driver?.lastName}',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'UberMove',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${driver?.id}',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        fontFamily: 'UberMove',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusBadge(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildDriverRatingCard(),
            const SizedBox(height: 20),

            // Contact Information
            _buildSection('Contact Information', [
              _buildInfoRow('Phone Number', driver?.phoneNumber ?? ''),
              _buildInfoRow('Email Address', driver?.email ?? ''),
              _buildInfoRow(
                'Date of Birth',
                driver?.dob?.toString().substring(0, 10) ?? 'Not provided',
              ),
            ]),

            // Identity Verification
            _buildSection('Identity Verification', [
              _buildInfoRow(
                'CNIC Number',
                driver?.cnicNumber ?? '',
                isVerified: driver?.cnicVerified ?? false,
              ),
              const SizedBox(height: 16),
              _buildDocumentCard('CNIC Front', driver?.cnicFrontUrl ?? ''),
              _buildDocumentCard('CNIC Back', driver?.cnicBackUrl ?? ''),
            ]),

            // Driving License
            _buildSection('Driving License', [
              _buildInfoRow(
                'License Number',
                driver?.licenseNumber ?? '',
                isVerified: driver?.licenseVerified ?? false,
              ),
              _buildInfoRow(
                'Expiry Date',
                driver?.licenseExpiry?.toString().substring(0, 10) ??
                    'Not provided',
              ),
              const SizedBox(height: 16),
              _buildDocumentCard(
                'License Photo',
                driver?.licensePhotoUrl ?? '',
              ),
            ]),

            // Vehicles
            if (vehicleList.isNotEmpty)
              ...vehicleList.asMap().entries.map(
                (entry) => _buildSection('Vehicle ${entry.key + 1} Details', [
                  _buildInfoRow('Vehicle Type', entry.value.type),
                  _buildInfoRow('Model', entry.value.model),
                  _buildInfoRow('Color', entry.value.color),
                  _buildInfoRow('Number Plate', entry.value.plate),
                  _buildInfoRow('Manufacturing Year', entry.value.year),
                  const SizedBox(height: 16),
                  _buildDocumentCard('Vehicle Photo', entry.value.photoUrl),
                  _buildDocumentCard(
                    'Registration Front',
                    entry.value.regFrontUrl,
                  ),
                  _buildDocumentCard(
                    'Registration Back',
                    entry.value.regBackUrl,
                  ),
                ]),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomSheet: Container(
        color: _backgroundColor,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _rejectDriver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: _textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontFamily: 'UberMove',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _approveDriver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontFamily: 'UberMove',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: const Text('Approve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
