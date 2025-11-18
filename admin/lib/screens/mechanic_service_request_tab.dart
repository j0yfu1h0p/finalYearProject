import 'package:admin/auth_service.dart';
import 'package:admin/screens/login.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

/// Administrative interface for managing mechanic service requests
/// Provides search, filtering, and detailed view of service request lifecycle
class MechanicServiceRequestsTab extends StatefulWidget {
  const MechanicServiceRequestsTab({Key? key}) : super(key: key);

  @override
  State<MechanicServiceRequestsTab> createState() =>
      _MechanicServiceRequestsTabState();
}

class _MechanicServiceRequestsTabState
    extends State<MechanicServiceRequestsTab> {
  // Authentication service for token management and authorization
  final AuthService _authService = AuthService();
  // Controller for search input field
  final TextEditingController _idSearchController = TextEditingController();

  // State variables
  List<Map<String, dynamic>> _requests =
      []; // List to store fetched mechanic requests
  bool _isLoading = true; // Loading state indicator
  String _error = ''; // Error message storage
  bool _showSearch = false; // Toggle search UI visibility

  @override
  void initState() {
    super.initState();
    // Fetch mechanic requests when widget initializes
    _fetchRequests();
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

  /// Fetches the latest mechanic service requests from the backend API
  /// Handles authentication, API communication, and response parsing with error handling
  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/mechanic-requests/latest',
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

        // The API returns the array directly
        final List<dynamic> requests = data is List ? data : [];

        setState(() {
          _requests = requests.map((r) {
            return {
              'id': r['_id']?.toString() ?? 'N/A',
              'status': r['status']?.toString() ?? 'N/A',
              'createdAt': r['createdAt']?.toString() ?? 'N/A',
              'userId': _extractUser(r['userId']),
              'mechanicId': _extractMechanic(r['mechanicId']),
              'serviceType': r['serviceType']?.toString() ?? 'N/A',
              'userLocation': _formatLocation(r['userLocation']),
              'notes': r['notes']?.toString() ?? 'No notes',
              'priceQuote': _formatPriceQuote(r['priceQuote']),
              'cancellation': _formatCancellation(r['cancellation']),
            };
          }).toList();
          _isLoading = false;
        });
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        setState(() {
          _error = 'Failed to fetch mechanic requests: ${res.statusCode}';
          _isLoading = false;
          _requests = [];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
        _requests = [];
      });

      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Failed to load requests: $e');
      }
    }
  }

  /// Extracts and formats user information from user data object
  /// Returns formatted string with name and phone number for display
  String _extractUser(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Map) {
      final phone = value['phoneNumber']?.toString() ?? '';
      final name = value['fullName']?.toString() ?? '';
      return name.isNotEmpty ? '$name ($phone)' : phone;
    }
    return value.toString();
  }

  /// Extracts and formats mechanic information from mechanic data object
  /// Returns formatted string with name/shop and phone number for display
  String _extractMechanic(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Map) {
      final phone = value['phoneNumber']?.toString() ?? '';
      final name =
          value['personName']?.toString() ??
          value['shopName']?.toString() ??
          '';
      return name.isNotEmpty ? '$name ($phone)' : phone;
    }
    return value.toString();
  }

  /// Formats geographic coordinates into human-readable latitude/longitude format
  /// Handles coordinate array parsing and precision formatting
  String _formatLocation(dynamic location) {
    if (location == null || location['coordinates'] == null) return 'N/A';
    final coords = location['coordinates'];
    if (coords is List && coords.length == 2) {
      return 'Lat: ${coords[1].toStringAsFixed(4)}, Lng: ${coords[0].toStringAsFixed(4)}';
    }
    return 'N/A';
  }

  /// Formats price quote information with currency symbol and amount
  /// Handles various price quote data structures and null values
  String _formatPriceQuote(dynamic priceQuote) {
    if (priceQuote == null) return 'Not quoted';
    if (priceQuote is Map) {
      final amount = priceQuote['amount']?.toString() ?? '0';
      final currency = priceQuote['currency']?.toString() ?? 'PKR';
      return '$currency $amount';
    }
    return 'Not quoted';
  }

  /// Formats cancellation information with reason and initiator details
  /// Provides comprehensive cancellation context for administrative review
  String _formatCancellation(dynamic cancellation) {
    if (cancellation == null) return 'Not cancelled';
    if (cancellation is Map) {
      final by = cancellation['cancelledBy']?.toString() ?? 'Unknown';
      final reason = cancellation['reason']?.toString() ?? 'No reason provided';
      return 'Cancelled by $by: $reason';
    }
    return 'Not cancelled';
  }

  /// Searches for specific mechanic request by ID from the backend API
  /// Provides direct access to individual records with comprehensive error handling
  Future<void> _searchByIdFromApi() async {
    final query = _idSearchController.text.trim();
    if (query.isEmpty) {
      _fetchRequests();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/mechanic-requests/$query',
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

        if (data['success'] == true && data['data'] != null) {
          final r = data['data'];
          setState(() {
            _requests = [
              {
                'id': r['_id']?.toString() ?? 'N/A',
                'status': r['status']?.toString() ?? 'N/A',
                'createdAt': r['createdAt']?.toString() ?? 'N/A',
                'userId': _extractUser(r['userId']),
                'mechanicId': _extractMechanic(r['mechanicId']),
                'serviceType': r['serviceType']?.toString() ?? 'N/A',
                'userLocation': _formatLocation(r['userLocation']),
                'notes': r['notes']?.toString() ?? 'No notes',
                'priceQuote': _formatPriceQuote(r['priceQuote']),
                'cancellation': _formatCancellation(r['cancellation']),
              },
            ];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'No mechanic request found for ID $query';
            _requests = [];
            _isLoading = false;
          });
        }
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else if (res.statusCode == 404) {
        setState(() {
          _error = 'No mechanic request found for ID $query';
          _requests = [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Search failed: ${res.statusCode}';
          _requests = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
        _requests = [];
      });

      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Search failed: $e');
      }
    }
  }

  /// Returns color code based on request status for visual indicators
  /// Provides consistent color coding across the application interface
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981); // Green
      case 'accepted':
      case 'arrived':
      case 'in-progress':
        return const Color(0xFF3B82F6); // Blue
      case 'pending':
        return const Color(0xFFF59E0B); // Amber
      case 'cancelled':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Returns appropriate icon based on request status for visual recognition
  /// Enhances user interface with intuitive status indicators
  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'accepted':
        return Icons.thumb_up;
      case 'arrived':
        return Icons.location_on;
      case 'in-progress':
        return Icons.build;
      case 'pending':
        return Icons.access_time;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  /// Converts ISO date string to human-readable format with error handling
  /// Provides consistent date formatting across the application
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd – HH:mm').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'UberMove'),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Mechanic Service Requests',
            style: TextStyle(
              fontFamily: 'UberMove',
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          actions: [
            // Toggle search visibility
            IconButton(
              icon: Icon(
                _showSearch ? Icons.close : Icons.search,
                color: const Color(0xFF1E293B),
              ),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _idSearchController.clear();
                    _fetchRequests();
                  }
                });
              },
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.1),
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_showSearch ? 60 : 1),
            child: Column(
              children: [
                if (_showSearch)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _idSearchController,
                            decoration: const InputDecoration(
                              hintText: 'Search mechanic request by ID',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _searchByIdFromApi(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFF10B981),
                          ),
                          onPressed: _searchByIdFromApi,
                        ),
                      ],
                    ),
                  ),
                Container(height: 1, color: const Color(0xFFE2E8F0)),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              )
            : _error.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _error,
                      style: const TextStyle(
                        fontFamily: 'UberMove',
                        fontSize: 16,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchRequests,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _requests.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No mechanic requests found',
                      style: TextStyle(
                        fontFamily: 'UberMove',
                        fontSize: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _fetchRequests,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchRequests,
                color: const Color(0xFF10B981),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    if (index >= _requests.length) {
                      return const SizedBox.shrink();
                    }
                    final request = _requests[index];
                    return _buildRequestCard(request);
                  },
                ),
              ),
      ),
    );
  }

  /// Constructs comprehensive card widget to display individual mechanic request details
  /// Organizes information in a structured, visually appealing layout
  Widget _buildRequestCard(Map<String, dynamic> request) {
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
            // Header with ID and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ID: ${request['id']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'UberMove',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Created: ${_formatDate(request['createdAt'])}',
                            style: const TextStyle(
                              fontFamily: 'UberMove',
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      request['status'] ?? 'unknown',
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusIcon(request['status'] ?? 'unknown'),
                        size: 14,
                        color: _statusColor(request['status'] ?? 'unknown'),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (request['status'] ?? 'UNKNOWN').toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'UberMove',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(request['status'] ?? 'unknown'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem(
              Icons.person_outline,
              'User',
              request['userId'] ?? 'N/A',
            ),
            _buildDetailItem(
              Icons.handyman,
              'Mechanic',
              request['mechanicId'] ?? 'N/A',
            ),
            _buildDetailItem(
              Icons.category,
              'Service Type',
              request['serviceType'] ?? 'N/A',
            ),
            _buildDetailItem(
              Icons.location_on,
              'User Location',
              request['userLocation'] ?? 'N/A',
            ),
            _buildDetailItem(
              Icons.notes,
              'Notes',
              request['notes'] ?? 'No notes',
            ),
            _buildDetailItem(
              Icons.attach_money,
              'Price Quote',
              request['priceQuote'] ?? 'Not quoted',
            ),
            if (request['cancellation'] != 'Not cancelled')
              _buildDetailItem(
                Icons.cancel,
                'Cancellation',
                request['cancellation'] ?? 'Not cancelled',
              ),
          ],
        ),
      ),
    );
  }

  /// Creates standardized detail row with icon, label, and value
  /// Ensures consistent information display across request cards
  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
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
                  style: const TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
