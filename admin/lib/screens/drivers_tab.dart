import 'package:admin/screens/driver_detail_screen.dart';
import 'package:admin/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class DriversTab extends StatefulWidget {
  const DriversTab({Key? key}) : super(key: key);

  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchDrivers();
  }

  void _handleUnauthorized() {
    _authService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );

    SnackBarUtil.showError(context, 'Session expired. Please login again.');
  }

  String _formatPhoneNumber(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.startsWith('92') && digitsOnly.length >= 10) {
      return '+$digitsOnly';
    }
    if (digitsOnly.length >= 10 && !digitsOnly.startsWith('92')) {
      return '+92$digitsOnly';
    }
    return phone;
  }

  Future<void> _searchDrivers() async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final search = _searchCtrl.text.trim();
      String? phone, name;

      if (search.isNotEmpty) {
        if (RegExp(r'^[\d+\s()-]+$').hasMatch(search)) {
          phone = _formatPhoneNumber(search);
        } else {
          name = search;
        }
      }

      final query = {
        if (phone != null) 'phoneNumber': phone,
        if (name != null) 'name': name,
        if (_selectedFilter != 'All') 'status': _selectedFilter.toLowerCase(),
        'limit': '20',
        'page': '1',
      };

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/drivers/search',
      ).replace(queryParameters: query);

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
          _drivers = (data['data'] as List)
              .map(
                (e) => {
                  'id': e['id'],
                  'fullName': e['fullName'],
                  'mobile': e['phoneNumber'],
                  'status': e['registrationStatus'],
                  'vehicleCount': e['vehicleCount'],
                  'registrationDate': e['registrationDate'],
                  'rating': _asDouble(e['rating']),
                  'ratingCount': _asInt(e['ratingCount']),
                },
              )
              .toList();
          _isLoading = false;
        });
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        throw Exception('Failed to fetch drivers: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Search failed: $e');
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.schedule_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Driver Management',
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
            icon: Icon(
              _isSearchVisible ? Icons.close : Icons.search,
              color: const Color(0xFF1E293B),
            ),
            onPressed: () {
              setState(() {
                if (_isSearchVisible) {
                  _searchCtrl.clear();
                  _searchDrivers();
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
                  hintText: 'Search by phone or ID...',
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
                    onPressed: _searchDrivers,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onSubmitted: (value) => _searchDrivers(),
              ),
            ),

          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Drivers',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_drivers.length} drivers found',
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
                            Icons.trending_up,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Active',
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
                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['All', 'pending', 'approved', 'rejected', 'uncertain']
                            .map(
                              (filter) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(
                                    filter.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'UberMove',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedFilter == filter
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                  selected: _selectedFilter == filter,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedFilter = filter);
                                      _searchDrivers();
                                    }
                                  },
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  selectedColor: _statusColor(filter),
                                  checkmarkColor: Colors.white,
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF10B981),
                      ),
                    ),
                  )
                : _drivers.isEmpty
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
                            Icons.person_search,
                            size: 48,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No drivers found',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try adjusting your search or filter criteria',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _drivers.length,
                    itemBuilder: (context, index) {
                      final driver = _drivers[index];
                      final double rating =
                          (driver['rating'] as double?) ?? 0.0;
                      final int ratingCount =
                          (driver['ratingCount'] as int?) ?? 0;
                      final String ratingLabel = ratingCount > 0
                          ? '${rating.toStringAsFixed(1)} / 5'
                          : 'No reviews yet';
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
                                            color: const Color(
                                              0xFF10B981,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Color(0xFF10B981),
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
                                                driver['fullName'] ?? 'Unknown',
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
                                                'ID: ${driver['id']}',
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        driver['status']!,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _statusIcon(driver['status']!),
                                          size: 14,
                                          color: _statusColor(
                                            driver['status']!,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          driver['status']!.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'UberMove',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _statusColor(
                                              driver['status']!,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailItem(
                                      Icons.phone_outlined,
                                      'Mobile',
                                      driver['mobile'] ?? 'N/A',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailItem(
                                      Icons.directions_car_outlined,
                                      'Vehicles',
                                      '${driver['vehicleCount'] ?? 0}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailItem(
                                      Icons.star_rate_rounded,
                                      'Rating',
                                      ratingLabel,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailItem(
                                      Icons.people_outline,
                                      'Reviews',
                                      ratingCount.toString(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              _buildDetailItem(
                                Icons.calendar_today_outlined,
                                'Registration Date',
                                _formatDate(driver['registrationDate']),
                              ),
                              const SizedBox(height: 16),

                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              DriverDetailScreen(
                                                driverId: driver['id'],
                                              ),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Edit',
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

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
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
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
