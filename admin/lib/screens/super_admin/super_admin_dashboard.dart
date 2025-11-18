import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../login.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final AuthService _authService = AuthService();
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  bool _isProfileLoading = false;
  String _errorMessage = '';
  int _currentSection = 0;

  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color darkGreen = Color(0xFF27AE60);
  static const Color lightGreen = Color(0xFF58D68D);
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF8F9FA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color selectedTabColor = Color(0xFF2ECC71);
  static const Color unselectedTabColor = Color(0xFF666666);
  static const Color errorColor = Color(0xFFE74C3C);

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchProfile();
  }

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

  Future<void> _fetchStats() async {
    try {
      final url =
          'https://smiling-sparrow-proper.ngrok-free.app/api/admin/stats';
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
          _stats = jsonDecode(res.body);
          _isLoading = false;
          _errorMessage = '';
        });
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        throw Exception('Failed to fetch stats: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load dashboard data';
      });

      if (e is! String || !e.contains('Navigator')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  Future<void> _refreshProfile() async {
    await _fetchProfile();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile updated'), backgroundColor: primaryGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        title: const Text(
          'Super Admin Dashboard',
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'UberMove',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textPrimary),
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: Icon(Icons.account_circle, color: textPrimary),
            onPressed: () {
              setState(
                () => _currentSection = 3,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
              ),
            )
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontFamily: 'UberMove',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchStats,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildSectionTabs(),
                Expanded(child: _buildCurrentSection()),
              ],
            ),
    );
  }

  Widget _buildSectionTabs() {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _SectionTab(
            title: 'Overview',
            isSelected: _currentSection == 0,
            onTap: () => setState(() => _currentSection = 0),
          ),
          _SectionTab(
            title: 'Analytics',
            isSelected: _currentSection == 1,
            onTap: () => setState(() => _currentSection = 1),
          ),
          _SectionTab(
            title: 'Trends',
            isSelected: _currentSection == 2,
            onTap: () => setState(() => _currentSection = 2),
          ),
          _SectionTab(
            title: 'Profile',
            isSelected: _currentSection == 3,
            onTap: () => setState(() => _currentSection = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildAnalyticsSection();
      case 2:
        return _buildTrendsSection();
      case 3:
        return _buildProfileSection();
      default:
        return _buildOverviewSection();
    }
  }

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
          _buildProfileHeader(),
          const SizedBox(height: 24),

          _buildProfileInfoCard(),
          const SizedBox(height: 16),

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
                  'SA',
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
            _profile['username']?.toString() ?? 'Super Admin',
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
              onTap: () {
                _fetchStats();
                _fetchProfile();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Data refreshed successfully'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              color: primaryGreen,
            ),
            const SizedBox(height: 12),
            _AccountActionButton(
              icon: Icons.lock_reset,
              label: 'Change Password',
              onTap: () {
                _showChangePasswordDialog();
              },
              color: darkGreen,
            ),
            const SizedBox(height: 12),
            _AccountActionButton(
              icon: Icons.logout,
              label: 'Logout',
              onTap: _logout,
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
            ));
        },
      ),
    );
  }

  Widget _buildOverviewSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Platform Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCardGrid(),
          const SizedBox(height: 16),
          _buildQuickStatsCard(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 16),
          _buildRevenueCard(),
        ],
      ),
    );
  }

  Widget _buildTrendsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Platform Trends',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 16),
          _buildServiceRequestsCard(),
          const SizedBox(height: 16),
          _buildRegistrationTrendsCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCardGrid() {
    return Container(
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
            const Text(
              'Key Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                fontFamily: 'UberMove',
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const double itemSpacing = 12;
                final double itemWidth =
                    (constraints.maxWidth - itemSpacing) / 2;
                return Wrap(
                  spacing: itemSpacing,
                  runSpacing: itemSpacing,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _StatCard(
                        title: 'Total Drivers',
                        value: _stats['totalDrivers']?.toString() ?? '0',
                        icon: Icons.local_taxi,
                        color: primaryGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatCard(
                        title: 'Total Mechanics',
                        value: _stats['totalMechanics']?.toString() ?? '0',
                        icon: Icons.build,
                        color: lightGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatCard(
                        title: 'Total Customers',
                        value: _stats['totalCustomers']?.toString() ?? '0',
                        icon: Icons.people_outline,
                        color: darkGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatCard(
                        title: 'Pending Registrations',
                        value:
                            _stats['totalPendingRegistrations']?.toString() ??
                            '0',
                        icon: Icons.pending_actions,
                        color: primaryGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatCard(
                        title: 'Active Requests',
                        value: _stats['totalActiveRequests']?.toString() ?? '0',
                        icon: Icons.trending_up,
                        color: lightGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatCard(
                        title: 'Completed Requests',
                        value:
                            _stats['totalCompletedRequests']?.toString() ?? '0',
                        icon: Icons.check_circle_outline,
                        color: darkGreen,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    final formatCurrency = NumberFormat.currency(
      symbol: '\PKR ',
      decimalDigits: 0,
    );

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
                    Icons.analytics_outlined,
                    color: primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Revenue Overview',
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
            Column(
              children: [
                _RevenueCardItem(
                  title: 'Monthly Revenue',
                  value: formatCurrency.format(
                    _stats['totalMonthlyRevenue'] ?? 0,
                  ),
                  trend: (_stats['totalMonthlyRevenue'] ?? 0) > 0
                      ? 'up'
                      : 'neutral',
                  period: 'This Month',
                ),
                const SizedBox(height: 12),
                _RevenueCardItem(
                  title: 'Yearly Revenue',
                  value: formatCurrency.format(
                    _stats['totalYearlyRevenue'] ?? 0,
                  ),
                  trend: (_stats['totalYearlyRevenue'] ?? 0) > 0
                      ? 'up'
                      : 'neutral',
                  period: 'This Year',
                ),
                const SizedBox(height: 12),
                _RevenueCardItem(
                  title: 'All Time Revenue',
                  value: formatCurrency.format(
                    _stats['totalAllTimeRevenue'] ?? 0,
                  ),
                  trend: 'up',
                  period: 'Total',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceRequestsCard() {
    List<Map<String, dynamic>> serviceData = [];
    List<Map<String, dynamic>> mechanicData = [];

    if (_stats['serviceRequestTrends'] != null) {
      for (var trend in _stats['serviceRequestTrends']) {
        serviceData.add({'date': trend['_id'], 'count': trend['count']});
      }
    }

    if (_stats['mechanicRequestTrends'] != null) {
      for (var trend in _stats['mechanicRequestTrends']) {
        mechanicData.add({'date': trend['_id'], 'count': trend['count']});
      }
    }

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
                    color: lightGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: lightGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Service Request Trends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last 7 Days Performance',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontFamily: 'UberMove',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                primaryXAxis: CategoryAxis(
                  labelStyle: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontFamily: 'UberMove',
                  ),
                  axisLine: const AxisLine(color: Colors.transparent),
                  majorGridLines: const MajorGridLines(
                    color: Colors.transparent,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  labelStyle: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontFamily: 'UberMove',
                  ),
                  axisLine: const AxisLine(color: Colors.transparent),
                  majorGridLines: MajorGridLines(
                    color: Colors.black.withOpacity(0.1),
                  ),
                ),
                legend: Legend(
                  isVisible: true,
                  textStyle: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontFamily: 'UberMove',
                  ),
                  position: LegendPosition.bottom,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  LineSeries<Map<String, dynamic>, String>(
                    dataSource: serviceData,
                    xValueMapper: (Map<String, dynamic> data, _) =>
                        data['date'].toString(),
                    yValueMapper: (Map<String, dynamic> data, _) =>
                        data['count'],
                    name: 'Ride Requests',
                    color: primaryGreen,
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                  LineSeries<Map<String, dynamic>, String>(
                    dataSource: mechanicData,
                    xValueMapper: (Map<String, dynamic> data, _) =>
                        data['date'].toString(),
                    yValueMapper: (Map<String, dynamic> data, _) =>
                        data['count'],
                    name: 'Mechanic Requests',
                    color: lightGreen,
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTrendsCard() {
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
                    color: darkGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    color: darkGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Recent Signups',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last 7 Days Registration',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontFamily: 'UberMove',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                backgroundColor: Colors.transparent,
                plotAreaBackgroundColor: Colors.transparent,
                primaryXAxis: CategoryAxis(
                  labelStyle: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontFamily: 'UberMove',
                  ),
                  axisLine: const AxisLine(color: Colors.transparent),
                  majorGridLines: const MajorGridLines(
                    color: Colors.transparent,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  labelStyle: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontFamily: 'UberMove',
                  ),
                  axisLine: const AxisLine(color: Colors.transparent),
                  majorGridLines: MajorGridLines(
                    color: Colors.black.withOpacity(0.1),
                  ),
                ),
                legend: Legend(
                  isVisible: true,
                  textStyle: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontFamily: 'UberMove',
                  ),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: [
                      {
                        'category': 'Drivers',
                        'value': _stats['recentDriverSignups'] ?? 0,
                      },
                      {
                        'category': 'Mechanics',
                        'value': _stats['recentMechanicSignups'] ?? 0,
                      },
                    ],
                    xValueMapper: (Map<String, dynamic> data, _) =>
                        data['category'],
                    yValueMapper: (Map<String, dynamic> data, _) =>
                        data['value'],
                    name: 'New Signups',
                    color: primaryGreen,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    width: 0.5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
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
                  child: const Icon(Icons.speed, color: primaryGreen, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                _QuickStatItem(
                  label: 'Driver Signups',
                  value: _stats['recentDriverSignups']?.toString() ?? '0',
                  icon: Icons.local_taxi,
                ),
                _buildDivider(),
                _QuickStatItem(
                  label: 'Mechanic Signups',
                  value: _stats['recentMechanicSignups']?.toString() ?? '0',
                  icon: Icons.build,
                ),
                _buildDivider(),
                _QuickStatItem(
                  label: 'Pending Drivers',
                  value: _stats['pendingDrivers']?.toString() ?? '0',
                  icon: Icons.hourglass_empty,
                ),
                _buildDivider(),
                _QuickStatItem(
                  label: 'Pending Mechanics',
                  value: _stats['pendingMechanics']?.toString() ?? '0',
                  icon: Icons.pending,
                ),
                _buildDivider(),
                _QuickStatItem(
                  label: 'Active Rides',
                  value: _stats['activeRequests']?.toString() ?? '0',
                  icon: Icons.directions_car,
                ),
                _buildDivider(),
                _QuickStatItem(
                  label: 'Active Services',
                  value: _stats['activeMechanicRequests']?.toString() ?? '0',
                  icon: Icons.handyman,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 1,
      color: borderColor,
    );
  }
}

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
            color: _SuperAdminDashboardState.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: _SuperAdminDashboardState.primaryGreen,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _SuperAdminDashboardState.textSecondary,
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
              color: valueColor ?? _SuperAdminDashboardState.textPrimary,
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
        color: _SuperAdminDashboardState.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SuperAdminDashboardState.borderColor),
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
            color: _SuperAdminDashboardState.textPrimary,
            fontFamily: 'UberMove',
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: _SuperAdminDashboardState.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? _SuperAdminDashboardState.selectedTabColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? _SuperAdminDashboardState.selectedTabColor
                  : _SuperAdminDashboardState.unselectedTabColor,
              fontFamily: 'UberMove',
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SuperAdminDashboardState.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SuperAdminDashboardState.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _SuperAdminDashboardState.textPrimary,
                        fontFamily: 'UberMove',
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _SuperAdminDashboardState.textSecondary,
                      fontFamily: 'UberMove',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _RevenueCardItem extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final String period;

  const _RevenueCardItem({
    required this.title,
    required this.value,
    required this.trend,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (trend == 'up') {
      icon = Icons.trending_up;
      color = _SuperAdminDashboardState.primaryGreen;
    } else if (trend == 'down') {
      icon = Icons.trending_down;
      color = Colors.redAccent;
    } else {
      icon = Icons.trending_flat;
      color = _SuperAdminDashboardState.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _SuperAdminDashboardState.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SuperAdminDashboardState.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                period,
                style: const TextStyle(
                  fontSize: 10,
                  color: _SuperAdminDashboardState.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'UberMove',
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _SuperAdminDashboardState.textPrimary,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: _SuperAdminDashboardState.textSecondary,
              fontFamily: 'UberMove',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _QuickStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _SuperAdminDashboardState.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            color: _SuperAdminDashboardState.primaryGreen,
            size: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _SuperAdminDashboardState.textSecondary,
              fontFamily: 'UberMove',
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _SuperAdminDashboardState.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _SuperAdminDashboardState.primaryGreen,
              fontFamily: 'UberMove',
            ),
          ),
        ),
      ],
    );
  }
}
