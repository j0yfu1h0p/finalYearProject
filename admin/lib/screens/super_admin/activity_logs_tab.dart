import 'package:admin/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ActivityLogsTab extends StatefulWidget {
  const ActivityLogsTab({Key? key}) : super(key: key);

  @override
  State<ActivityLogsTab> createState() => _ActivityLogsTabState();
}

class _ActivityLogsTabState extends State<ActivityLogsTab> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalLogs = 0;
  final int _limit = 20;

  // Entity type definitions with icons and colors
  final Map<String, Map<String, dynamic>> _entityTypes = {
    "driver": {
      "label": "Driver",
      "icon": Icons.person_outline,
      "color": Color(0xFF3B82F6),
    },
    "customer": {
      "label": "Customer",
      "icon": Icons.person,
      "color": Color(0xFF10B981),
    },
    "request": {
      "label": "Service Request",
      "icon": Icons.assignment,
      "color": Color(0xFFF59E0B),
    },
    "admin": {
      "label": "Admin",
      "icon": Icons.admin_panel_settings,
      "color": Color(0xFFEF4444),
    },
    "mechanic": {
      "label": "Mechanic",
      "icon": Icons.build,
      "color": Color(0xFF8B5CF6),
    },
  };

  // User type definitions
  final Map<String, Map<String, dynamic>> _userTypes = {
    "Admin": {
      "label": "Admin",
      "color": Color(0xFFEF4444),
    },
    "User": {
      "label": "Customer",
      "color": Color(0xFF10B981),
    },
    "Driver": {
      "label": "Driver",
      "color": Color(0xFF3B82F6),
    },
    "Mechanic": {
      "label": "Mechanic",
      "color": Color(0xFF8B5CF6),
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  /// Handles unauthorized access by redirecting to login
  void _handleUnauthorized() {
    // Clear any existing tokens
    _authService.logout();

    // Navigate to login page and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
    );

    // Show a message to the user
    SnackBarUtil.showError(context, 'Session expired. Please login again.');
  }

  /// Fetches activity logs with pagination
  Future<void> _fetchLogs({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final queryParams = {
        'page': page.toString(),
        'limit': _limit.toString(),
      };

      final uri = Uri.parse('https://smiling-sparrow-proper.ngrok-free.app/api/admin/activity-logs')
          .replace(queryParameters: queryParams);

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
          _logs = (data['logs'] as List)
              .map((e) => {
            'id': e['_id'],
            'action': e['action'],
            'description': e['description'],
            'entityType': e['entityType'],
            'entityId': e['entityId'],
            'performedBy': e['performedBy'] is Map ? e['performedBy'] : null,
            'userType': e['userType'],
            'metadata': e['metadata'],
            'isError': e['isError'] ?? false,
            'errorDetails': e['errorDetails'],
            'timestamp': e['timestamp'],
          })
              .toList();
          _totalLogs = data['total'] ?? 0;
          _currentPage = data['page'] ?? 1;
          _totalPages = data['pages'] ?? 1;
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

  /// Formats timestamp to readable format
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy - HH:mm:ss').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  /// Gets relative time (e.g., "2 hours ago")
  String _getRelativeTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM dd').format(date);
    } catch (e) {
      return '';
    }
  }

  /// Builds entity type display
  Widget _buildEntityTypeChip(String entityType) {
    final entity = _entityTypes[entityType];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: entity?['color']?.withOpacity(0.1) ?? Color(0xFF6B7280).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entity?['icon'] ?? Icons.category,
            size: 12,
            color: entity?['color'] ?? Color(0xFF6B7280),
          ),
          const SizedBox(width: 4),
          Text(
            entity?['label'] ?? entityType,
            style: TextStyle(
              fontFamily: 'UberMove',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: entity?['color'] ?? Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds user type display
  Widget _buildUserTypeChip(String userType) {
    final user = _userTypes[userType];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: user?['color']?.withOpacity(0.1) ?? Color(0xFF6B7280).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        user?['label'] ?? userType,
        style: TextStyle(
          fontFamily: 'UberMove',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: user?['color'] ?? Color(0xFF6B7280),
        ),
      ),
    );
  }

  /// Builds error indicator
  Widget _buildErrorIndicator(bool isError) {
    if (!isError) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 12, color: Color(0xFFEF4444)),
          const SizedBox(width: 2),
          Text(
            'Error',
            style: TextStyle(
              fontFamily: 'UberMove',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Activity Logs',
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
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            onPressed: () => _fetchLogs(page: 1),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          // Dashboard header (simplified - removed stats)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Logs',
                  style: TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Recent system activities',
                  style: TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Main content area with logs list
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
                : _logs.isEmpty
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
                      Icons.analytics_outlined,
                      size: 48,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No activity logs',
                    style: TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Activities will appear here as they occur',
                    style: TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _fetchLogs(page: 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isError = log['isError'] == true;
                final performedBy = log['performedBy'] is Map ? log['performedBy'] : null;
                final username = performedBy?['username'] ?? 'System';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with action and metadata
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['action'] ?? 'Unknown Action',
                                    style: TextStyle(
                                      fontFamily: 'UberMove',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isError ? Color(0xFFEF4444) : Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (log['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      log['description']!,
                                      style: const TextStyle(
                                        fontFamily: 'UberMove',
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildErrorIndicator(isError),
                                const SizedBox(height: 4),
                                Text(
                                  _getRelativeTime(log['timestamp']),
                                  style: const TextStyle(
                                    fontFamily: 'UberMove',
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Metadata row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (log['entityType'] != null)
                              _buildEntityTypeChip(log['entityType']),
                            if (log['userType'] != null)
                              _buildUserTypeChip(log['userType']),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    username,
                                    style: const TextStyle(
                                      fontFamily: 'UberMove',
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Timestamp and details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimestamp(log['timestamp']),
                              style: const TextStyle(
                                fontFamily: 'UberMove',
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            if (isError && log['errorDetails'] != null)
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xFFEF4444),
                              ),
                          ],
                        ),

                        // Error details (expanded on tap if needed)
                        if (isError && log['errorDetails'] != null)
                          const SizedBox(height: 8),
                        if (isError && log['errorDetails'] != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              log['errorDetails']!,
                              style: TextStyle(
                                fontFamily: 'UberMove',
                                fontSize: 12,
                                color: Color(0xFFDC2626),
                              ),
                            ),
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
}