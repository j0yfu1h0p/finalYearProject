import 'package:admin/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'drivers_tab.dart';
import 'customers_tab.dart';
import 'mechanic_service_request_tab.dart';
import 'mechanics_tab.dart';
import 'requests_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  // Profile and stats data
  Map<String, dynamic> _profile = {};
  bool _isProfileLoading = false;
  int _currentSection = 0; // 0: Main content, 1: Profile

  // Color scheme matching SuperAdminDashboard
  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color darkGreen = Color(0xFF27AE60);
  static const Color lightGreen = Color(0xFF58D68D);
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF8F9FA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFE74C3C);

  /// Navigation screens corresponding to each tab
  late final List<Widget> _screens;

  /// Bottom navigation bar items including profile as final item
  late final List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _initializeNavigationComponents();
    _checkAuthentication();
  }

  /// Initializes navigation screens and items
  void _initializeNavigationComponents() {
    _screens = const [
      DriversTab(),
      CustomersTab(),
      RequestsTab(),
      MechanicsTab(),
      MechanicServiceRequestsTab(),
    ];

    _navItems = const [
      BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Drivers'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Customers'),
      BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Requests'),
      BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Mechanics'),
      BottomNavigationBarItem(icon: Icon(Icons.handyman), label: 'Service Req'),
      BottomNavigationBarItem(
        icon: Icon(Icons.account_circle),
        label: 'Profile',
      ),
    ];
  }

  /// Validates user authentication status
  Future<void> _checkAuthentication() async {
    setState(() => _isLoading = true);
    _isAuthenticated = await _authService.isAuthenticated();
    if (_isAuthenticated) {
      await _fetchProfile();
    }
    setState(() => _isLoading = false);
  }

  /// Handles unauthorized access by redirecting to login
  void _handleUnauthorized() {
    _authService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session expired. Please login again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Fetch admin profile data
  Future<void> _fetchProfile() async {
    setState(() {
      _isProfileLoading = true;
    });

    try {
      final url =
          'https://smiling-sparrow-proper.ngrok-free.app/api/admin/profile';
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          _profile = jsonDecode(res.body);
          _isProfileLoading = false;
        });
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        throw Exception('Failed to fetch profile: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isProfileLoading = false;
      });
    }
  }

  /// Change password API call
  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final url =
          'https://smiling-sparrow-proper.ngrok-free.app/api/admin/change-password';
      final token = await _authService.getToken();

      if (token == null) {
        _handleUnauthorized();
        throw Exception('Authentication required');
      }

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to change password');
      } else if (response.statusCode == 401) {
        _handleUnauthorized();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Admin account not found');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('Network error: Please check your connection');
      } else if (e is FormatException) {
        throw Exception('Invalid server response');
      } else {
        throw e;
      }
    }
  }

  /// Refresh profile data
  Future<void> _refreshProfile() async {
    await _fetchProfile();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile updated'), backgroundColor: primaryGreen),
    );
  }

  /// Logout function
  Future<void> _logout() async {
    try {
      await _authService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
    }
  }

  /// Displays confirmation dialog for logout action
  Future<void> _showLogoutDialog() async {
    final navigator = Navigator.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[Text('Are you sure you want to logout?')],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout();
              },
            ),
          ],
        );
      },
    );
  }

  /// Handles navigation item selection
  void _onNavTap(int index) {
    if (index == _navItems.length - 1) {
      // Profile tab clicked - switch to profile section
      setState(() => _currentSection = 1);
    } else {
      setState(() {
        _currentIndex = index;
        _currentSection = 0; // Switch back to main content
      });
    }
  }

  /// Build profile section
  Widget _buildProfileSection() {
    if (_isProfileLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Back to dashboard button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: TextButton.icon(
              onPressed: () => setState(() => _currentSection = 0),
              icon: Icon(Icons.arrow_back, color: primaryGreen),
              label: Text(
                'Back to Dashboard',
                style: TextStyle(color: primaryGreen, fontFamily: 'UberMove'),
              ),
            ),
          ),

          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: 24),

          // Profile Information Card
          _buildProfileInfoCard(),
          const SizedBox(height: 16),

          // Account Actions Card
          _buildAccountActionsCard(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: primaryGreen,
            child: Text(
              _profile['username']?.toString().substring(0, 2).toUpperCase() ??
                  'AD',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'UberMove',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profile['username']?.toString() ?? 'Admin',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _profile['role'] == 'superadmin'
                  ? darkGreen
                  : primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _profile['role']?.toString().toUpperCase() ?? 'ADMIN',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'UberMove',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    final DateFormat dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFamily: 'UberMove',
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  color: textSecondary,
                  onPressed: _refreshProfile,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileInfoItem(
              icon: Icons.person,
              label: 'Username',
              value: _profile['username']?.toString() ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _ProfileInfoItem(
              icon: Icons.security,
              label: 'Role',
              value: _profile['role']?.toString().toUpperCase() ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _ProfileInfoItem(
              icon: Icons.circle,
              label: 'Status',
              value: _profile['active'] == true ? 'Active' : 'Inactive',
              valueColor: _profile['active'] == true
                  ? primaryGreen
                  : errorColor,
            ),
            const SizedBox(height: 12),
            _ProfileInfoItem(
              icon: Icons.calendar_today,
              label: 'Member Since',
              value: _profile['createdAt'] != null
                  ? dateFormat.format(DateTime.parse(_profile['createdAt']))
                  : 'N/A',
            ),
            const SizedBox(height: 12),
            _ProfileInfoItem(
              icon: Icons.login,
              label: 'Last Login',
              value: _profile['lastLogin'] != null
                  ? dateFormat.format(DateTime.parse(_profile['lastLogin']))
                  : 'Never logged in',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Account Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AccountActionButton(
              icon: Icons.refresh,
              label: 'Refresh Data',
              onTap: _refreshProfile,
              color: primaryGreen,
            ),
            const SizedBox(height: 12),
            _AccountActionButton(
              icon: Icons.lock_reset,
              label: 'Change Password',
              onTap: _showChangePasswordDialog,
              color: darkGreen,
            ),
            const SizedBox(height: 12),
            _AccountActionButton(
              icon: Icons.logout,
              label: 'Logout',
              onTap: _showLogoutDialog,
              color: errorColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    bool _isLoading = false;
    String _errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          fontFamily: 'UberMove',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: errorColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: errorColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: errorColor,
                                fontSize: 12,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_errorMessage.isNotEmpty) const SizedBox(height: 16),

                  // Current Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: currentPasswordController,
                          obscureText: true,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'UberMove',
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            hintText: 'Enter current password',
                            hintStyle: TextStyle(
                              color: Color(0xFF999999),
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // New Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'UberMove',
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            hintText: 'Enter new password',
                            hintStyle: TextStyle(
                              color: Color(0xFF999999),
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'UberMove',
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            hintText: 'Confirm new password',
                            hintStyle: TextStyle(
                              color: Color(0xFF999999),
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Password Requirements
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password Requirements',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textSecondary,
                            fontFamily: 'UberMove',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: newPasswordController.text.length >= 6
                                  ? primaryGreen
                                  : textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'At least 6 characters long',
                              style: TextStyle(
                                fontSize: 10,
                                color: newPasswordController.text.length >= 6
                                    ? primaryGreen
                                    : textSecondary,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color:
                                  newPasswordController.text ==
                                          confirmPasswordController.text &&
                                      newPasswordController.text.isNotEmpty
                                  ? primaryGreen
                                  : textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Passwords must match',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    newPasswordController.text ==
                                            confirmPasswordController.text &&
                                        newPasswordController.text.isNotEmpty
                                    ? primaryGreen
                                    : textSecondary,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: borderColor),
                            backgroundColor: background,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  // Validate inputs
                                  if (currentPasswordController.text.isEmpty) {
                                    setState(
                                      () => _errorMessage =
                                          'Current password is required',
                                    );
                                    return;
                                  }

                                  if (newPasswordController.text.isEmpty) {
                                    setState(
                                      () => _errorMessage =
                                          'New password is required',
                                    );
                                    return;
                                  }

                                  if (newPasswordController.text.length < 6) {
                                    setState(
                                      () => _errorMessage =
                                          'New password must be at least 6 characters long',
                                    );
                                    return;
                                  }

                                  if (newPasswordController.text !=
                                      confirmPasswordController.text) {
                                    setState(
                                      () => _errorMessage =
                                          'New passwords do not match',
                                    );
                                    return;
                                  }

                                  setState(() {
                                    _isLoading = true;
                                    _errorMessage = '';
                                  });

                                  try {
                                    await _changePassword(
                                      currentPasswordController.text,
                                      newPasswordController.text,
                                    );

                                    // Close dialog on success
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Password changed successfully',
                                          ),
                                          backgroundColor: primaryGreen,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _isLoading = false;
                                      _errorMessage = e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      );
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            disabledBackgroundColor: primaryGreen.withOpacity(
                              0.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Update',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentSection == 1
          ? AppBar(
              backgroundColor: background,
              elevation: 1,
              shadowColor: Colors.black.withOpacity(0.1),
              title: const Text(
                'Admin Profile',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'UberMove',
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary),
                onPressed: () => setState(() => _currentSection = 0),
              ),
            )
          : null,
      body: !_isAuthenticated
          ? const Center(
              child: Text(
                'You are not authenticated',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
          : _currentSection == 1
          ? _buildProfileSection()
          : _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey[600],
        currentIndex: _currentSection == 1
            ? _navItems.length - 1
            : _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onNavTap,
        items: _navItems,
      ),
    );
  }
}

// Profile-specific widgets
class _ProfileInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _AdminDashboardState.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: _AdminDashboardState.primaryGreen, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _AdminDashboardState.textSecondary,
              fontFamily: 'UberMove',
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _AdminDashboardState.textPrimary,
              fontFamily: 'UberMove',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _AccountActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _AccountActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AdminDashboardState.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AdminDashboardState.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _AdminDashboardState.textPrimary,
            fontFamily: 'UberMove',
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: _AdminDashboardState.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
