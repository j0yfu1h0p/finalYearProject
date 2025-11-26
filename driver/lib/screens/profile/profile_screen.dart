import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';

class ProfilePageScreen extends StatefulWidget {
  const ProfilePageScreen({super.key});

  @override
  _ProfilePageScreenState createState() => _ProfilePageScreenState();
}

class _ProfilePageScreenState extends State<ProfilePageScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> driverProfile = {};
  Map<String, dynamic> mechanicProfile = {};
  bool isLoading = true;
  String errorMessage = '';
  String? driverProfilePhotoUrl;
  String? mechanicProfilePhotoUrl;

  // Tab controller for switching between Driver and Mechanic views
  late TabController _tabController;
  String? driverStatus;
  String? mechanicStatus;
  List<String> availableTabs = [];

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  Future<void> _loadUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverStatus = prefs.getString('driverStatus');
      mechanicStatus = prefs.getString('mechanicStatus');

      // Determine which tabs to show - only if status is 'approved'
      if (driverStatus == 'approved') availableTabs.add('Driver');
      if (mechanicStatus == 'approved') availableTabs.add('Mechanic');

      // Initialize tab controller with the number of available tabs
      _tabController = TabController(
        length: availableTabs.length,
        vsync: this,
        initialIndex: 0,
      );
    });

    await fetchUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchUserProfile() async {
    try {
      final token = await Auth.getToken();

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Not authenticated';
        });
        return;
      }

      // Fetch driver profile if driver status is approved
      if (driverStatus == 'approved') {
        final driverResponse = await http.get(
          Uri.parse(
            'https://smiling-sparrow-proper.ngrok-free.app/api/driver/profile',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (driverResponse.statusCode == 200) {
          final data = json.decode(driverResponse.body);
          setState(() {
            driverProfile = data;
            // Extract profile photo URL for driver
            if (data['personal_info'] != null &&
                data['personal_info']['profile_photo_url'] != null &&
                data['personal_info']['profile_photo_url'].isNotEmpty) {
              driverProfilePhotoUrl =
                  data['personal_info']['profile_photo_url'];
            }
          });
        } else {
          setState(() {
            errorMessage =
                'Failed to load driver profile: ${driverResponse.statusCode}';
          });
        }
      }

      // Fetch mechanic profile if mechanic status is approved
      if (mechanicStatus == 'approved') {
        final mechanicResponse = await http.get(
          Uri.parse(
            'https://smiling-sparrow-proper.ngrok-free.app/api/mechanic/profile',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (mechanicResponse.statusCode == 200) {
          final data = json.decode(mechanicResponse.body);
          setState(() {
            mechanicProfile = data['data'] ?? {};
            // Set profile photo for mechanic
            if (mechanicProfile['personalPhotoUrl'] != null &&
                mechanicProfile['personalPhotoUrl'].isNotEmpty) {
              mechanicProfilePhotoUrl = mechanicProfile['personalPhotoUrl'];
            }
          });
        } else {
          setState(() {
            errorMessage =
                'Failed to load mechanic profile: ${mechanicResponse.statusCode}';
          });
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            fontFamily: 'UberMove',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: availableTabs.length > 1
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                tabs: availableTabs.map((tab) => Tab(text: tab)).toList(),
              )
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(child: Text('Error: $errorMessage'))
          : availableTabs.length > 1
          ? TabBarView(
              controller: _tabController,
              children: availableTabs.map((tab) {
                if (tab == 'Driver') return _buildDriverProfile();
                return _buildMechanicProfile();
              }).toList(),
            )
          : _buildProfileForSingleRole(),
    );
  }

  Widget _buildProfileForSingleRole() {
    if (driverStatus == 'approved') return _buildDriverProfile();
    if (mechanicStatus == 'approved') return _buildMechanicProfile();

    // If no approved roles, show appropriate message
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Approved Profiles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Driver Status: ${driverStatus ?? 'Not registered'}',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Mechanic Status: ${mechanicStatus ?? 'Not registered'}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverProfile() {
    final personalInfo = driverProfile['personal_info'] ?? {};
    final identification = driverProfile['identification'] ?? {};
    final license = driverProfile['license'] ?? {};
    final vehicles = driverProfile['vehicles'] ?? [];
    final double? driverRating = _parseAverage(
      driverProfile['rating'] ?? driverProfile['averageRating'],
    );
    final int? driverReviewCount = _parseReviewCount(
      driverProfile['ratingCount'] ?? driverProfile['rating_count'],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              children: [
                // Profile Picture
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: driverProfilePhotoUrl != null
                        ? NetworkImage(driverProfilePhotoUrl!)
                        : null,
                    child: driverProfilePhotoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Name Section
                _buildInfoCard(
                  icon: Icons.person_outline,
                  title: "Name",
                  value:
                      "${personalInfo['first_name'] ?? ''} ${personalInfo['last_name'] ?? ''}"
                          .trim()
                          .isEmpty
                      ? "Not provided"
                      : "${personalInfo['first_name'] ?? ''} ${personalInfo['last_name'] ?? ''}",
                ),
                const SizedBox(height: 12),

                // Phone Number Section
                _buildInfoCard(
                  icon: Icons.phone_outlined,
                  title: "Phone",
                  value:
                      driverProfile['phoneNumber']?.toString() ??
                      "Not provided",
                ),
                const SizedBox(height: 12),

                // Email Section
                _buildInfoCard(
                  icon: Icons.email_outlined,
                  title: "Email",
                  value: (personalInfo['email']?.isNotEmpty == true)
                      ? personalInfo['email']
                      : "Not provided",
                ),
                const SizedBox(height: 12),

                // Date of Birth Section
                _buildInfoCard(
                  icon: Icons.cake_outlined,
                  title: "Date of Birth",
                  value: personalInfo['date_of_birth'] != null
                      ? _formatDate(personalInfo['date_of_birth'])
                      : "Not provided",
                ),
                const SizedBox(height: 12),

                // CNIC Section
                _buildInfoCard(
                  icon: Icons.credit_card_outlined,
                  title: "CNIC",
                  value:
                      identification['cnic_number']?.toString() ??
                      "Not provided",
                ),
                const SizedBox(height: 12),

                // License Section
                _buildInfoCard(
                  icon: Icons.drive_eta_outlined,
                  title: "License Number",
                  value:
                      license['license_number']?.toString() ?? "Not provided",
                ),
                const SizedBox(height: 12),

                // License Expiry Section
                _buildInfoCard(
                  icon: Icons.calendar_today_outlined,
                  title: "License Expiry",
                  value: license['expiry_date'] != null
                      ? _formatDate(license['expiry_date'])
                      : "Not provided",
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildRatingSummary(
            averageRating: driverRating,
            reviewCount: driverReviewCount,
            accentColor: Colors.amber,
            label: 'Driver rating',
            helperText: driverReviewCount != null && driverReviewCount > 0
                ? 'Your average updates after every completed trip.'
                : 'Complete more trips to build your public rating.',
          ),
          const SizedBox(height: 16),

          // Documents Section
          if (identification['cnic_front_url'] != null ||
              identification['cnic_back_url'] != null ||
              license['license_photo_url'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Documents",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontFamily: 'UberMove',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CNIC Front
                  if (identification['cnic_front_url'] != null)
                    _buildDocumentItem(
                      "CNIC Front",
                      identification['cnic_front_url'],
                    ),

                  // CNIC Back
                  if (identification['cnic_back_url'] != null)
                    _buildDocumentItem(
                      "CNIC Back",
                      identification['cnic_back_url'],
                    ),

                  // License Photo
                  if (license['license_photo_url'] != null)
                    _buildDocumentItem("License", license['license_photo_url']),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Vehicle Information
          if (vehicles != null && vehicles.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Vehicle Information",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontFamily: 'UberMove',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...vehicles.map<Widget>((vehicle) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVehicleInfo("Type", vehicle['vehicle_type']),
                        _buildVehicleInfo("Model", vehicle['company_model']),
                        _buildVehicleInfo("Color", vehicle['color']),
                        _buildVehicleInfo("Plate", vehicle['number_plate']),
                        _buildVehicleInfo(
                          "Year",
                          vehicle['manufacturing_year'],
                        ),
                        if (vehicles.length > 1) const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Registration Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Registration Information",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontFamily: 'UberMove',
                  ),
                ),
                const SizedBox(height: 8),
                _buildRegistrationInfo(
                  "Status",
                  personalInfo['registration_status'] ?? "Unknown",
                ),
                _buildRegistrationInfo(
                  "Date",
                  personalInfo['registration_date'] != null
                      ? _formatDate(personalInfo['registration_date'])
                      : "Not available",
                ),
                _buildRegistrationInfo(
                  "Last Updated",
                  personalInfo['last_updated'] != null
                      ? _formatDate(personalInfo['last_updated'])
                      : "Not available",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicProfile() {
    final double? mechanicRating = _parseAverage(
      mechanicProfile['rating'] ?? mechanicProfile['averageRating'],
    );
    final int? mechanicReviewCount = _parseReviewCount(
      mechanicProfile['ratingCount'] ?? mechanicProfile['rating_count'],
    );
    final servicesOffered = mechanicProfile['servicesOffered'];
    List<dynamic> servicesList = const [];
    if (servicesOffered is List && servicesOffered.isNotEmpty) {
      servicesList = List<dynamic>.from(servicesOffered);
    }
    final bool hasServices = servicesList.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Card - More compact
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              children: [
                // Profile Picture
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: mechanicProfilePhotoUrl != null
                        ? NetworkImage(mechanicProfilePhotoUrl!)
                        : null,
                    child: mechanicProfilePhotoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Name Section
                _buildInfoCard(
                  icon: Icons.person_outline,
                  title: "Name",
                  value: mechanicProfile['personName'] ?? "Not provided",
                ),
                const SizedBox(height: 12),

                // Shop Name Section
                _buildInfoCard(
                  icon: Icons.store_outlined,
                  title: "Shop Name",
                  value: mechanicProfile['shopName'] ?? "Not provided",
                ),
                const SizedBox(height: 12),

                // Phone Number Section
                _buildInfoCard(
                  icon: Icons.phone_outlined,
                  title: "Phone",
                  value: mechanicProfile['phoneNumber'] ?? "Not provided",
                ),
                const SizedBox(height: 12),

                // Emergency Contact Section
                _buildInfoCard(
                  icon: Icons.emergency_outlined,
                  title: "Emergency Contact",
                  value: mechanicProfile['emergencyContact'] ?? "Not provided",
                ),
                const SizedBox(height: 12),

                // Address Section
                _buildInfoCard(
                  icon: Icons.location_on_outlined,
                  title: "Address",
                  value: mechanicProfile['address'] ?? "Not provided",
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildRatingSummary(
            averageRating: mechanicRating,
            reviewCount: mechanicReviewCount,
            accentColor: Colors.blueAccent,
            label: 'Workshop rating',
            helperText: mechanicReviewCount != null && mechanicReviewCount > 0
                ? 'Great service keeps you at the top of user searches.'
                : 'Finish more jobs to start collecting reviews.',
          ),

          const SizedBox(height: 16),

          // Services Offered
          if (hasServices)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Services Offered",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontFamily: 'UberMove',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: servicesList.map<Widget>((service) {
                      return Chip(
                        label: Text(service.toString()),
                        backgroundColor: Colors.blue[50],
                        labelStyle: const TextStyle(fontSize: 12),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Documents Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Documents",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontFamily: 'UberMove',
                  ),
                ),
                const SizedBox(height: 12),

                if (mechanicProfile['cnicPhotoUrl'] != null)
                  _buildDocumentItem("CNIC", mechanicProfile['cnicPhotoUrl']),

                if (mechanicProfile['registrationCertificateUrl'] != null)
                  _buildDocumentItem(
                    "Certificate",
                    mechanicProfile['registrationCertificateUrl'],
                  ),

                if (mechanicProfile['workshopPhotoUrl'] != null)
                  _buildDocumentItem(
                    "Workshop",
                    mechanicProfile['workshopPhotoUrl'],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Registration Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: mechanicProfile['registrationStatus'] == 'approved'
                  ? Colors.green
                  : (mechanicProfile['registrationStatus'] == 'pending'
                        ? Colors.orange
                        : Colors.red),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mechanicProfile['registrationStatus'] == 'approved'
                      ? Icons.verified
                      : (mechanicProfile['registrationStatus'] == 'pending'
                            ? Icons.pending
                            : Icons.error_outline),
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  mechanicProfile['registrationStatus'] == 'approved'
                      ? "Approved"
                      : (mechanicProfile['registrationStatus'] == 'pending'
                            ? "Pending Approval"
                            : "Rejected"),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary({
    required double? averageRating,
    required int? reviewCount,
    required Color accentColor,
    required String label,
    String? helperText,
  }) {
    final double safeRating = ((averageRating ?? 0.0).clamp(0.0, 5.0));
    final int totalReviews = reviewCount ?? 0;
    final bool hasReviews = totalReviews > 0;
    final String reviewLabel = hasReviews
        ? '$totalReviews review${totalReviews == 1 ? '' : 's'}'
        : 'No reviews yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, color: accentColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    fontFamily: 'UberMove',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasReviews ? safeRating.toStringAsFixed(1) : '--',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontFamily: 'UberMove',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      reviewLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontFamily: 'UberMove',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  helperText ??
                      (hasReviews
                          ? 'Latest reviews refresh in real time.'
                          : 'Once jobs are completed your public rating appears here.'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _parseAverage(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseReviewCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                    fontFamily: 'UberMove',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontFamily: 'UberMove',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : "Not provided",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'UberMove',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontFamily: 'UberMove',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'UberMove',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String title, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              // TODO: Implement image preview
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.grey),
                        const SizedBox(height: 4),
                        Text(
                          'Failed to load',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }
}
