import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../login.dart';

class AdminsTab extends StatefulWidget {
  const AdminsTab({Key? key}) : super(key: key);

  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  bool _isSearchVisible = false;
  bool _showCreateDialog = false;
  String? _selectedRole = 'admin';

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  /// Handles unauthorized access by redirecting to login
  void _handleUnauthorized() {
    // Clear any existing tokens
    _authService.logout();

    // Navigate to login page and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(),
      ), // Replace with your LoginPage widget
      (route) => false,
    );

    // Show a message to the user
    SnackBarUtil.showError(context, 'Session expired. Please login again.');
  }

  /// Fetches all admins
  Future<void> _fetchAdmins() async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/admins',
      );

      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _admins = (data as List)
              .map(
                (e) => {
                  'id': e['_id'],
                  'username': e['username'],
                  'role': e['role'],
                  'active': e['active'] ?? true,
                  'createdAt': e['createdAt'],
                },
              )
              .toList();
          _isLoading = false;
        });
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        throw Exception('Failed: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Creates a new admin
  Future<void> _createAdmin() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/admins',
      );

      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'role': _selectedRole,
        }),
      );

      if (res.statusCode == 201) {
        SnackBarUtil.showSuccess(context, 'Admin created successfully');
        _usernameCtrl.clear();
        _passwordCtrl.clear();
        setState(() => _showCreateDialog = false);
        _fetchAdmins();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['message'] ?? 'Failed to create admin');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Deletes an admin
  Future<void> _deleteAdmin(String adminId, String username) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/admins/$adminId',
      );

      final res = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        SnackBarUtil.showSuccess(context, 'Admin deleted successfully');
        _fetchAdmins();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['message'] ?? 'Failed to delete admin');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Updates admin role
  Future<void> _updateAdminRole(String adminId, String newRole) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/admins/$adminId/role',
      );

      final res = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'role': newRole}),
      );

      if (res.statusCode == 200) {
        SnackBarUtil.showSuccess(context, 'Admin role updated successfully');
        _fetchAdmins();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['message'] ?? 'Failed to update role');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Updates admin status
  Future<void> _updateAdminStatus(String adminId, bool active) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/admins/$adminId/status',
      );

      final res = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'active': active}),
      );

      if (res.statusCode == 200) {
        SnackBarUtil.showSuccess(context, 'Admin status updated successfully');
        _fetchAdmins();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Shows delete confirmation dialog
  void _showDeleteDialog(String adminId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin'),
        content: Text('Are you sure you want to delete admin "$username"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAdmin(adminId, username);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Shows role update dialog
  void _showRoleDialog(String adminId, String currentRole) {
    String? newRole = currentRole;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Admin Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select new role:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: newRole,
                items: ['admin', 'superadmin']
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => newRole = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newRole != null) {
                  Navigator.pop(context);
                  _updateAdminRole(adminId, newRole!);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows create admin dialog with modern design
  void _showCreateAdminDialog() {
    _usernameCtrl.clear();
    _passwordCtrl.clear();
    _selectedRole = 'admin';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create New Admin',
                              style: TextStyle(
                                fontFamily: 'UberMove',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Add administrator account',
                              style: TextStyle(
                                fontFamily: 'UberMove',
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Compact Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Admin credentials section
                        _buildCompactSection(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Admin Credentials',
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              // Username field
                              _buildCompactTextField(
                                controller: _usernameCtrl,
                                label: 'Username *',
                                hintText: 'Enter username',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                              // Password field
                              _buildCompactTextField(
                                controller: _passwordCtrl,
                                label: 'Password *',
                                hintText: 'Enter password',
                                icon: Icons.lock_outline,
                                obscureText: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Role selection section
                        _buildCompactSection(
                          icon: Icons.security_rounded,
                          title: 'Admin Role',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedRole == null
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFF10B981),
                                    width: 1.5,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedRole,
                                    isExpanded: true,
                                    icon: const Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: Icon(
                                        Icons.arrow_drop_down,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'UberMove',
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                    items: ['admin', 'superadmin']
                                        .map(
                                          (role) => DropdownMenuItem(
                                            value: role,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    role == 'superadmin'
                                                        ? Icons.security
                                                        : Icons
                                                              .admin_panel_settings,
                                                    color: _roleColor(role),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          role.toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                                fontFamily:
                                                                    'UberMove',
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        Text(
                                                          role == 'superadmin'
                                                              ? 'Full system access with all privileges'
                                                              : 'Standard administrator access',
                                                          style:
                                                              const TextStyle(
                                                                fontFamily:
                                                                    'UberMove',
                                                                fontSize: 11,
                                                                color: Color(
                                                                  0xFF64748B,
                                                                ),
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedRole = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              if (_selectedRole != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: const Color(0xFF10B981),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _selectedRole!.toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'UberMove',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedRole == 'superadmin'
                                            ? 'Full Access'
                                            : 'Standard Access',
                                        style: const TextStyle(
                                          fontFamily: 'UberMove',
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                        // Helper text
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: const Color(0xFF64748B).withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Admin will be created with active status',
                                style: TextStyle(
                                  fontFamily: 'UberMove',
                                  fontSize: 10,
                                  color: const Color(
                                    0xFF64748B,
                                  ).withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Compact Footer buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _usernameCtrl.clear();
                            _passwordCtrl.clear();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'UberMove',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_usernameCtrl.text.isEmpty) {
                              SnackBarUtil.showError(
                                context,
                                'Please enter a username',
                              );
                              return;
                            }
                            if (_passwordCtrl.text.isEmpty) {
                              SnackBarUtil.showError(
                                context,
                                'Please enter a password',
                              );
                              return;
                            }
                            if (_passwordCtrl.text.length < 6) {
                              SnackBarUtil.showError(
                                context,
                                'Password must be at least 6 characters',
                              );
                              return;
                            }

                            Navigator.pop(context);
                            _createAdmin();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Create Admin',
                                style: TextStyle(
                                  fontFamily: 'UberMove',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to build compact sections
  Widget _buildCompactSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFF10B981), size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'UberMove',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// Helper method to build compact text fields
  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'UberMove',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: const TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontFamily: 'UberMove',
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Returns color based on admin role
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Returns icon based on admin role
  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return Icons.security;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  /// Returns status color
  Color _statusColor(bool isActive) {
    return isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
  }

  /// Returns status icon
  IconData _statusIcon(bool isActive) {
    return isActive ? Icons.check_circle : Icons.cancel;
  }

  /// Formats ISO date string to readable format
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd – HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Admin Management',
          style: TextStyle(
            fontFamily: 'UberMove',
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF1E293B)),
            onPressed: _showCreateAdminDialog, // Updated to use new dialog
          ),
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.close : Icons.search,
              color: const Color(0xFF1E293B),
            ),
            onPressed: () {
              setState(() {
                if (_isSearchVisible) {
                  _searchCtrl.clear();
                  _fetchAdmins();
                }
                _isSearchVisible = !_isSearchVisible;
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: Column(
        children: [
          // Search bar (visible when toggled)
          if (_isSearchVisible)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'UberMove',
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  hintStyle: const TextStyle(
                    fontFamily: 'UberMove',
                    color: Color(0xFF64748B),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF64748B),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF10B981),
                    ),
                    onPressed: () {
                      // Implement search functionality
                      _fetchAdmins();
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onSubmitted: (value) => _fetchAdmins(),
              ),
            ),

          // Dashboard header
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with title and stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Administrators',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_admins.length} admins found',
                          style: const TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Secure',
                            style: TextStyle(
                              fontFamily: 'UberMove',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main content area with admin list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF10B981),
                      ),
                    ),
                  )
                : _admins.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 48,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No admins found',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a new admin to get started',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showCreateAdminDialog,
                          child: const Text('Create First Admin'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _admins.length,
                    itemBuilder: (context, index) {
                      final admin = _admins[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                              // Admin header with username and role
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _roleColor(
                                              admin['role']!,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            _roleIcon(admin['role']!),
                                            color: _roleColor(admin['role']!),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                admin['username'] ?? 'Unknown',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'UberMove',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: ${admin['id']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'UberMove',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Role badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _roleColor(
                                        admin['role']!,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _roleIcon(admin['role']!),
                                          size: 14,
                                          color: _roleColor(admin['role']!),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          admin['role']!.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'UberMove',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _roleColor(admin['role']!),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Admin details row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailItem(
                                      Icons.calendar_today_outlined,
                                      'Created',
                                      _formatDate(admin['createdAt']),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailItem(
                                      Icons.circle,
                                      'Status',
                                      admin['active'] ? 'Active' : 'Inactive',
                                      statusColor: _statusColor(
                                        admin['active'],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Status toggle button
                                  IconButton(
                                    icon: Icon(
                                      admin['active']
                                          ? Icons.toggle_on
                                          : Icons.toggle_off,
                                      color: admin['active']
                                          ? Color(0xFF10B981)
                                          : Color(0xFFEF4444),
                                      size: 30,
                                    ),
                                    onPressed: () {
                                      _updateAdminStatus(
                                        admin['id'],
                                        !admin['active'],
                                      );
                                    },
                                    tooltip: admin['active']
                                        ? 'Deactivate'
                                        : 'Activate',
                                  ),
                                  const SizedBox(width: 8),

                                  // Role update button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: GestureDetector(
                                      onTap: () => _showRoleDialog(
                                        admin['id'],
                                        admin['role'],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.swap_horiz,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Change Role',
                                            style: TextStyle(
                                              fontFamily: 'UberMove',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Delete button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: GestureDetector(
                                      onTap: () => _showDeleteDialog(
                                        admin['id'],
                                        admin['username'],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Delete',
                                            style: TextStyle(
                                              fontFamily: 'UberMove',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
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
          ),
        ],
      ),
    );
  }

  /// Builds a detail item row with icon, label and value
  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value, {
    Color? statusColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: statusColor ?? const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'UberMove',
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'UberMove',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: statusColor ?? const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
