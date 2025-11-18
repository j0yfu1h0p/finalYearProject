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

class _ProfilePageScreenState extends State<ProfilePageScreen> {
  String userName = "Loading...";
  String mobileNumber = "Loading...";
  bool isLoading = true;
  String errorMessage = '';

  // API configuration
  static const String profileApiUrl = 'https://smiling-sparrow-proper.ngrok-free.app/api/v1/users/profile';
  static const String defaultName = 'Not provided';
  static const String defaultPhone = 'Not provided';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Fetches user profile data from the API
  Future<void> _loadUserProfile() async {
    try {
      final token = await Auth.getToken();

      if (token == null || token.isEmpty) {
        _handleError('Authentication required');
        return;
      }

      final response = await http.get(
        Uri.parse(profileApiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      _handleProfileResponse(response);
    } catch (e) {
      _handleError('Network error: Please check your connection');
    }
  }

  // Processes the API response and updates state accordingly
  void _handleProfileResponse(http.Response response) {
    if (!mounted) return;

    try {
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true && data['user'] is Map<String, dynamic>) {
          final userData = data['user'] as Map<String, dynamic>;
          setState(() {
            userName = userData['name']?.toString() ?? defaultName;
            mobileNumber = userData['phone']?.toString() ?? defaultPhone;
            isLoading = false;
            errorMessage = '';
          });
        } else {
          _handleError(data['message']?.toString() ?? 'Failed to load profile data');
        }
      } else if (response.statusCode == 401) {
        _handleError('Authentication expired. Please login again.');
      } else {
        _handleError('Server error: ${response.statusCode}');
      }
    } on FormatException {
      _handleError('Invalid response format from server');
    } catch (e) {
      _handleError('Unexpected error occurred');
    }
  }

  // Handles errors by updating state with error message
  void _handleError(String message) {
    if (!mounted) return;

    setState(() {
      errorMessage = message;
      isLoading = false;
      userName = defaultName;
      mobileNumber = defaultPhone;
    });
  }

  // Builds the profile information section with icon and text
  Widget _buildProfileSection(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
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
                    fontSize: 18,
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Error: $errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontFamily: 'UberMove',
            ),
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Section
                  _buildProfileSection("Name", userName, Icons.person_outline),
                  const SizedBox(height: 16),

                  // Phone Number Section
                  _buildProfileSection("Phone Number", mobileNumber, Icons.phone_outlined),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Information Banner
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Your Profile Information",
                    style: TextStyle(
                      fontSize: 14,
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
      ),
    );
  }
}