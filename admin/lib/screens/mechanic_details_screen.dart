import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:admin/screens/login.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

/// Represents mechanic entity with comprehensive business and verification data
/// Includes personal information, workshop details, and registration documents
class Mechanic {
  final String id;
  final String phoneNumber;
  final String personName;
  final String shopName;
  final String personalPhotoUrl;
  final String cnicPhotoUrl;
  final String workshopPhotoUrl;
  final String introductionVideoUrl;
  final String registrationCertificateUrl;
  final String emergencyContact;
  final List<String> servicesOffered;
  final Map<String, dynamic> location;
  final String address;
  String registrationStatus;
  final bool isActive;
  final DateTime createdAt;

  Mechanic.fromJson(Map<String, dynamic> json)
      : id = json['_id'] ?? '',
        phoneNumber = json['phoneNumber'] ?? '',
        personName = json['personName'] ?? '',
        shopName = json['shopName'] ?? '',
        personalPhotoUrl = json['personalPhotoUrl'] ?? '',
        cnicPhotoUrl = json['cnicPhotoUrl'] ?? '',
        workshopPhotoUrl = json['workshopPhotoUrl'] ?? '',
        introductionVideoUrl = json['introductionVideoUrl'] ?? '',
        registrationCertificateUrl = json['registrationCertificateUrl'] ?? '',
        emergencyContact = json['emergencyContact'] ?? '',
        servicesOffered = (json['servicesOffered'] as List? ?? []).cast<String>(),
        location = json['location'] ?? {},
        address = json['address'] ?? '',
        registrationStatus = json['registrationStatus'] ?? 'uncertain',
        isActive = json['isActive'] ?? true,
        createdAt = DateTime.parse(
          json['createdAt'] ?? DateTime.now().toString(),
        );
}

/// Administrative service class for mechanic management operations
/// Handles API communication for mechanic details, approval, and status updates
class MechanicService {
  final String _baseUrl =
      'https://smiling-sparrow-proper.ngrok-free.app/api/admin';
  final AuthService _authService = AuthService();

  /// Retrieves detailed mechanic information from the API
  /// Throws exception on network errors, unauthorized access, or invalid responses
  Future<Mechanic> getMechanicDetails(String mechanicId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/mechanics/$mechanicId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Mechanic.fromJson(data['mechanic']);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else {
      throw Exception(
        'Failed to load mechanic details: ${response.statusCode}',
      );
    }
  }

  /// Approves mechanic registration after verification process
  /// Updates mechanic status to approved in the system
  Future<void> approveMechanic(String mechanicId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/mechanics/$mechanicId/approve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else if (response.statusCode != 200) {
      throw Exception('Failed to approve mechanic: ${response.statusCode}');
    }
  }

  /// Rejects mechanic registration with proper status update
  /// Prevents mechanic from accessing platform services
  Future<void> rejectMechanic(String mechanicId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/mechanics/$mechanicId/reject'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else if (response.statusCode != 200) {
      throw Exception('Failed to reject mechanic: ${response.statusCode}');
    }
  }

  /// Sets mechanic status to pending for further review
  /// Used when additional verification or information is required
  Future<void> setPendingMechanic(String mechanicId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/mechanics/$mechanicId/pending'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else if (response.statusCode != 200) {
      throw Exception(
        'Failed to set mechanic to pending: ${response.statusCode}',
      );
    }
  }

  /// Sets mechanic status to uncertain for manual intervention
  /// Used when automatic verification cannot determine status
  Future<void> setUncertainMechanic(String mechanicId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/mechanics/$mechanicId/uncertain'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access');
    } else if (response.statusCode != 200) {
      throw Exception(
        'Failed to set mechanic to uncertain: ${response.statusCode}',
      );
    }
  }
}

/// Detailed view screen for mechanic verification and management
/// Provides comprehensive mechanic information with multiple status update options
class MechanicDetailScreen extends StatefulWidget {
  final String mechanicId;

  const MechanicDetailScreen({super.key, required this.mechanicId});

  @override
  State<MechanicDetailScreen> createState() => _MechanicDetailScreenState();
}

class _MechanicDetailScreenState extends State<MechanicDetailScreen> {
  Mechanic? mechanic;
  bool isLoading = true;

  /// Uber-inspired color scheme for consistent white theme UI
  static const Color _backgroundColor = Colors.white;
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textPrimary = Colors.black;
  static const Color _textSecondary = Colors.grey;
  static const Color _accentColor = Colors.green;
  static const Color _errorColor = Colors.red;
  static const Color _warningColor = Colors.orange;
  static const Color _uncertainColor = Colors.purple;

  final MechanicService _mechanicService = MechanicService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchMechanicDetails();
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

  /// Fetches mechanic details from API with authentication and error handling
  /// Updates UI state based on API response success or failure
  Future<void> _fetchMechanicDetails() async {
    try {
      final fetchedMechanic = await _mechanicService.getMechanicDetails(
        widget.mechanicId,
      );
      setState(() {
        mechanic = fetchedMechanic;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (e.toString().contains('Unauthorized')) {
        _handleUnauthorized();
      } else {
        _showErrorDialog('Failed to load mechanic details: $e');
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

  /// Shows confirmation dialog for critical actions like status changes
  /// Ensures user intent before executing registration status updates
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

  /// Processes mechanic approval with status updates and user feedback
  /// Handles API communication errors and unauthorized access scenarios
  void _approveMechanic() {
    _showConfirmationDialog(
      'Approve Mechanic',
      'Are you sure you want to approve this mechanic?',
          () async {
        try {
          await _mechanicService.approveMechanic(widget.mechanicId);
          setState(() {
            mechanic?.registrationStatus = 'approved';
          });
          SnackBarUtil.showSuccess(context, 'Mechanic approved successfully');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) {
            _handleUnauthorized();
          } else {
            _showErrorDialog('Failed to approve mechanic: $e');
          }
        }
      },
    );
  }

  /// Processes mechanic rejection with appropriate status change
  /// Provides error handling for API failures and authentication issues
  void _rejectMechanic() {
    _showConfirmationDialog(
      'Reject Mechanic',
      'Are you sure you want to reject this mechanic?',
          () async {
        try {
          await _mechanicService.rejectMechanic(widget.mechanicId);
          setState(() {
            mechanic?.registrationStatus = 'rejected';
          });
          SnackBarUtil.showError(context, 'Mechanic rejected');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) {
            _handleUnauthorized();
          } else {
            _showErrorDialog('Failed to reject mechanic: $e');
          }
        }
      },
    );
  }

  /// Sets mechanic status to pending for additional review requirements
  /// Used when documentation or verification needs further examination
  void _setPendingMechanic() {
    _showConfirmationDialog(
      'Set to Pending',
      'Are you sure you want to set this mechanic to pending?',
          () async {
        try {
          await _mechanicService.setPendingMechanic(widget.mechanicId);
          setState(() {
            mechanic?.registrationStatus = 'pending';
          });
          SnackBarUtil.showWarning(context, 'Mechanic status set to pending');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) {
            _handleUnauthorized();
          } else {
            _showErrorDialog('Failed to set mechanic to pending: $e');
          }
        }
      },
    );
  }

  /// Sets mechanic status to uncertain for manual decision making
  /// Used when automated systems cannot determine appropriate status
  void _setUncertainMechanic() {
    _showConfirmationDialog(
      'Set to Uncertain',
      'Are you sure you want to set this mechanic to uncertain?',
          () async {
        try {
          await _mechanicService.setUncertainMechanic(widget.mechanicId);
          setState(() {
            mechanic?.registrationStatus = 'uncertain';
          });
          SnackBarUtil.showInfo(context, 'Mechanic status set to uncertain');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) {
            _handleUnauthorized();
          } else {
            _showErrorDialog('Failed to set mechanic to uncertain: $e');
          }
        }
      },
    );
  }

  /// Opens document images and videos in external viewer or browser
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
  /// Supports consistent information display across different sections
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
  /// Displays current registration status with appropriate styling for multiple states
  Widget _buildStatusBadge() {
    final status = mechanic?.registrationStatus?.toLowerCase() ?? 'uncertain';
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
      case 'pending':
        color = _warningColor;
        text = 'Pending Review';
        break;
      default:
        color = _uncertainColor;
        text = 'Uncertain';
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
                'Loading mechanic details...',
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text(
          'Mechanic Details',
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
                          'Approve Mechanic',
                          style: TextStyle(
                            color: _textPrimary,
                            fontFamily: 'UberMove',
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _approveMechanic();
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
                          _setPendingMechanic();
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.help_outline,
                          color: _uncertainColor,
                        ),
                        title: const Text(
                          'Mark as Uncertain',
                          style: TextStyle(
                            color: _textPrimary,
                            fontFamily: 'UberMove',
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _setUncertainMechanic();
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
                          _rejectMechanic();
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
            // Mechanic Profile Header
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
                      mechanic?.personalPhotoUrl.isNotEmpty == true
                          ? NetworkImage(mechanic!.personalPhotoUrl)
                          : null,
                      child: mechanic?.personalPhotoUrl.isEmpty == true
                          ? const Icon(
                        Icons.person,
                        size: 50,
                        color: _textSecondary,
                      )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      mechanic?.personName ?? 'Unknown',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'UberMove',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shop: ${mechanic?.shopName ?? 'N/A'}',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 16,
                        fontFamily: 'UberMove',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${mechanic?.id}',
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

            // Contact Information
            _buildSection('Contact Information', [
              _buildInfoRow('Phone Number', mechanic?.phoneNumber ?? ''),
              _buildInfoRow(
                'Emergency Contact',
                mechanic?.emergencyContact ?? '',
              ),
              _buildInfoRow(
                'Registration Date',
                mechanic?.createdAt.toString().substring(0, 10) ?? '',
              ),
            ]),

            // Business Information
            _buildSection('Business Information', [
              _buildInfoRow('Shop Name', mechanic?.shopName ?? ''),
              _buildInfoRow('Address', mechanic?.address ?? ''),
              _buildInfoRow(
                'Services Offered',
                mechanic?.servicesOffered.join(', ') ?? '',
              ),
            ]),

            // Documents
            _buildSection('Documents', [
              _buildDocumentCard(
                'Personal Photo',
                mechanic?.personalPhotoUrl ?? '',
              ),
              _buildDocumentCard('CNIC Photo', mechanic?.cnicPhotoUrl ?? ''),
              _buildDocumentCard(
                'Workshop Photo',
                mechanic?.workshopPhotoUrl ?? '',
              ),
              if (mechanic?.introductionVideoUrl?.isNotEmpty == true)
                _buildDocumentCard(
                  'Introduction Video',
                  mechanic!.introductionVideoUrl,
                ),
              _buildDocumentCard(
                'Registration Certificate',
                mechanic?.registrationCertificateUrl ?? '',
              ),
            ]),

            // Location Information
            if (mechanic?.location != null && mechanic!.location.isNotEmpty)
              _buildSection('Location', [
                _buildInfoRow(
                  'Coordinates',
                  '${mechanic!.location['coordinates']?[0] ?? 'N/A'}, ${mechanic!.location['coordinates']?[1] ?? 'N/A'}',
                ),
              ]),

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
                onPressed: _rejectMechanic,
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
                onPressed: _approveMechanic,
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