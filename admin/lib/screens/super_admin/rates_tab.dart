import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../login.dart';

class RatesTab extends StatefulWidget {
  const RatesTab({Key? key}) : super(key: key);

  @override
  State<RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<RatesTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _basePriceCtrl = TextEditingController();
  final TextEditingController _pricePerKmCtrl = TextEditingController();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _rates = [];
  bool _isLoading = true;
  bool _isSearchVisible = false;
  bool _showCreateDialog = false;
  String? _selectedServiceType;

  // Service type definitions with icons and descriptions
  final Map<String, Map<String, dynamic>> _serviceTypes = {
    "heavy_truck": {
      "label": "Heavy Truck",
      "icon": Icons.local_shipping,
      "description": "Towing for heavy trucks and commercial vehicles"
    },
    "two_wheeler": {
      "label": "Two Wheeler",
      "icon": Icons.two_wheeler,
      "description": "Motorcycles, scooters, and bikes"
    },
    "four_wheeler": {
      "label": "Four Wheeler",
      "icon": Icons.directions_car,
      "description": "Cars, SUVs, and light vehicles"
    },
    "car_lockout_service": {
      "label": "Car Lockout",
      "icon": Icons.lock_outline,
      "description": "Lockout assistance service"
    },
    "puncture_repair": {
      "label": "Puncture Repair",
      "icon": Icons.build,
      "description": "Tire puncture repair service"
    },
    "battery_jump_start": {
      "label": "Battery Jump Start",
      "icon": Icons.electrical_services,
      "description": "Battery jump start service"
    },
    "fuel_delivery": {
      "label": "Fuel Delivery",
      "icon": Icons.local_gas_station,
      "description": "Emergency fuel delivery"
    },
    "quote_after_inspection": {
      "label": "Quote After Inspection",
      "icon": Icons.assessment,
      "description": "Custom quote after vehicle inspection"
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  /// Handles unauthorized access by redirecting to login
  void _handleUnauthorized() {
    _authService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
    );

    SnackBarUtil.showError(context, 'Session expired. Please login again.');
  }

  /// Fetches all rates
  Future<void> _fetchRates() async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse('https://smiling-sparrow-proper.ngrok-free.app/api/trip/rates');

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
          _rates = (data as List)
              .map(
                (e) => {
              'id': e['_id'],
              'serviceType': e['serviceType'],
              'basePrice': _convertToDouble(e['basePrice']),
              'pricePerKm': _convertToDouble(e['pricePerKm']),
              'createdAt': e['createdAt'],
              'updatedAt': e['updatedAt'],
            },
          )
              .toList();
          _isLoading = false;
        });
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        throw Exception('Failed: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Helper method to safely convert any number type to double
  double? _convertToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Creates a new rate
  Future<void> _createRate() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      if (_selectedServiceType == null) {
        SnackBarUtil.showError(context, 'Please select a service type');
        return;
      }

      if (_basePriceCtrl.text.isEmpty) {
        SnackBarUtil.showError(context, 'Please enter a base price');
        return;
      }

      final basePrice = double.tryParse(_basePriceCtrl.text);
      if (basePrice == null) {
        SnackBarUtil.showError(context, 'Please enter a valid base price');
        return;
      }

      final uri = Uri.parse('https://smiling-sparrow-proper.ngrok-free.app/api/trip/rates');

      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'serviceType': _selectedServiceType,
          'basePrice': basePrice,
          'pricePerKm': _pricePerKmCtrl.text.isNotEmpty ? double.tryParse(_pricePerKmCtrl.text) : null,
        }),
      );

      if (res.statusCode == 201) {
        SnackBarUtil.showSuccess(context, 'Rate created successfully');
        _clearForm();
        setState(() => _showCreateDialog = false);
        _fetchRates();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['error'] ?? 'Failed to create rate');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Updates a rate
  Future<void> _updateRate(String rateId, double basePrice, double? pricePerKm) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse('https://smiling-sparrow-proper.ngrok-free.app/api/trip/rates/$rateId');

      final res = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'basePrice': basePrice,
          'pricePerKm': pricePerKm,
        }),
      );

      if (res.statusCode == 200) {
        SnackBarUtil.showSuccess(context, 'Rate updated successfully');
        _fetchRates();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['error'] ?? 'Failed to update rate');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Deletes a rate
  Future<void> _deleteRate(String rateId, String serviceType) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final uri = Uri.parse('https://smiling-sparrow-proper.ngrok-free.app/api/trip/rates/$rateId');

      final res = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        SnackBarUtil.showSuccess(context, 'Rate deleted successfully');
        _fetchRates();
      } else if (res.statusCode == 401) {
        // Unauthorized - redirect to login
        _handleUnauthorized();
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error['error'] ?? 'Failed to delete rate');
      }
    } catch (e) {
      // Only show error if it's not a navigation-related exception
      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Error: $e');
      }
    }
  }

  /// Clears the form fields
  void _clearForm() {
    _basePriceCtrl.clear();
    _pricePerKmCtrl.clear();
    _selectedServiceType = null;
  }

  /// Shows delete confirmation dialog
  void _showDeleteDialog(String rateId, String serviceType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rate'),
        content: Text('Are you sure you want to delete the rate for "${_serviceTypes[serviceType]?['label'] ?? serviceType}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRate(rateId, serviceType);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Shows edit rate dialog
  void _showEditDialog(Map<String, dynamic> rate) {
    final basePriceCtrl = TextEditingController(text: rate['basePrice'].toString());
    final pricePerKmCtrl = TextEditingController(text: rate['pricePerKm']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit ${_serviceTypes[rate['serviceType']]?['label'] ?? rate['serviceType']}',
                      style: const TextStyle(
                        fontFamily: 'UberMove',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Base Price Field
              _buildCompactTextField(
                controller: basePriceCtrl,
                label: 'Base Price',
                hintText: '0.00',
              ),
              const SizedBox(height: 16),

              // Price per Km Field
              _buildCompactTextField(
                controller: pricePerKmCtrl,
                label: 'Price per Km (Optional)',
                hintText: '0.00',
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final basePrice = double.tryParse(basePriceCtrl.text);
                        final pricePerKm = pricePerKmCtrl.text.isNotEmpty ? double.tryParse(pricePerKmCtrl.text) : null;

                        if (basePrice == null || basePrice <= 0) {
                          SnackBarUtil.showError(context, 'Please enter a valid base price');
                          return;
                        }

                        Navigator.pop(context);
                        _updateRate(rate['id'], basePrice, pricePerKm);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Update Rate', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows create rate dialog with compact design
  void _showCreateRateDialog() {
    _selectedServiceType = null;
    _basePriceCtrl.clear();
    _pricePerKmCtrl.clear();

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
                          Icons.attach_money_rounded,
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
                              'Create New Rate',
                              style: TextStyle(
                                fontFamily: 'UberMove',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Set service pricing',
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
                        // Service type selection - Compact
                        _buildCompactSection(
                          icon: Icons.category_rounded,
                          title: 'Service Type',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedServiceType == null
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFF10B981),
                                    width: 1.5,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedServiceType,
                                    isExpanded: true,
                                    icon: const Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'UberMove',
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                    items: _serviceTypes.entries
                                        .where((entry) => !_rates.any((rate) => rate['serviceType'] == entry.key))
                                        .map((entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              entry.value['icon'],
                                              color: _serviceColor(entry.key),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.value['label'],
                                                    style: const TextStyle(
                                                      fontFamily: 'UberMove',
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    entry.value['description'],
                                                    style: const TextStyle(
                                                      fontFamily: 'UberMove',
                                                      fontSize: 11,
                                                      color: Color(0xFF64748B),
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
                                    ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedServiceType = value;
                                      });
                                    },
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'Select service type',
                                        style: TextStyle(
                                          fontFamily: 'UberMove',
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedServiceType != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.05),
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
                                        _serviceTypes[_selectedServiceType]!['label'],
                                        style: const TextStyle(
                                          fontFamily: 'UberMove',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Pricing configuration - Compact
                        _buildCompactSection(
                          icon: Icons.currency_rupee_rounded,
                          title: 'Pricing',
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              // Base price field
                              _buildCompactTextField(
                                controller: _basePriceCtrl,
                                label: 'Base Price *',
                                hintText: '0.00',
                              ),
                              const SizedBox(height: 12),
                              // Price per km field
                              _buildCompactTextField(
                                controller: _pricePerKmCtrl,
                                label: 'Price per Km (Optional)',
                                hintText: '0.00',
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
                                      'Leave price per km empty for flat rate',
                                      style: TextStyle(
                                        fontFamily: 'UberMove',
                                        fontSize: 10,
                                        color: const Color(0xFF64748B).withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                      top: BorderSide(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _clearForm();
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
                            if (_selectedServiceType == null) {
                              SnackBarUtil.showError(context, 'Please select a service type');
                              return;
                            }
                            if (_basePriceCtrl.text.isEmpty) {
                              SnackBarUtil.showError(context, 'Please enter a base price');
                              return;
                            }

                            final basePrice = double.tryParse(_basePriceCtrl.text);
                            if (basePrice == null || basePrice <= 0) {
                              SnackBarUtil.showError(context, 'Please enter a valid base price');
                              return;
                            }

                            Navigator.pop(context);
                            _createRate();
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
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Create',
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
                child: Icon(
                  icon,
                  color: const Color(0xFF10B981),
                  size: 14,
                ),
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

  /// Helper method to build compact text fields with centered text and PKR
  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
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
                child: const Center(
                  child: Text(
                    'PKR',
                    style: TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                    contentPadding: EdgeInsets.zero,
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

  /// Returns color based on service type
  Color _serviceColor(String serviceType) {
    final colors = [
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFF84CC16),
    ];
    final index = _serviceTypes.keys.toList().indexOf(serviceType);
    return index >= 0 ? colors[index % colors.length] : Color(0xFF6B7280);
  }

  /// Formats price with currency
  String _formatPrice(double price) {
    return 'PKR ${price.toStringAsFixed(2)}';
  }

  /// Formats ISO date string to readable format
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  /// Builds service type display widget
  Widget _buildServiceTypeDisplay(String serviceType) {
    final service = _serviceTypes[serviceType];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _serviceColor(serviceType).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          service?['icon'] ?? Icons.category,
          color: _serviceColor(serviceType),
          size: 20,
        ),
      ),
      title: Text(
        service?['label'] ?? serviceType,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: service?['description'] != null
          ? Text(service!['description']!)
          : null,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _basePriceCtrl.dispose();
    _pricePerKmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Rates Management',
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
            onPressed: _showCreateRateDialog,
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
                  _fetchRates();
                }
                _isSearchVisible = !_isSearchVisible;
              });
            },
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
                  hintText: 'Search by service type...',
                  hintStyle: const TextStyle(
                      fontFamily: 'UberMove', color: Color(0xFF64748B)),
                  prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF64748B)),
                  suffixIcon: IconButton(
                    icon:
                    const Icon(Icons.arrow_forward, color: Color(0xFF10B981)),
                    onPressed: _fetchRates,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onSubmitted: (value) => _fetchRates(),
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
                          'Service Rates',
                          style: TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_rates.length} rates configured',
                          style: const TextStyle(
                            fontFamily: 'UberMove',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.attach_money,
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
              ],
            ),
          ),

          // Main content area with rates list
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
                : _rates.isEmpty
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
                      Icons.attach_money_outlined,
                      size: 48,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No rates configured',
                    style: TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create rates for different services',
                    style: TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showCreateRateDialog,
                    child: const Text('Create First Rate'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _rates.length,
              itemBuilder: (context, index) {
                final rate = _rates[index];
                final service = _serviceTypes[rate['serviceType']];
                final isDistanceBased = rate['pricePerKm'] != null && (rate['pricePerKm'] as double) > 0;

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
                        // Service header with name and pricing type
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
                                      color: _serviceColor(rate['serviceType'])
                                          .withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      service?['icon'] ?? Icons.category,
                                      color: _serviceColor(rate['serviceType']),
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
                                          service?['label'] ?? rate['serviceType'],
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
                                          service?['description'] ?? 'Service rate',
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
                            // Pricing type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDistanceBased
                                    ? Color(0xFF3B82F6).withOpacity(0.1)
                                    : Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDistanceBased
                                        ? Icons.trending_up
                                        : Icons.price_check,
                                    size: 14,
                                    color: isDistanceBased
                                        ? Color(0xFF3B82F6)
                                        : Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDistanceBased ? 'DISTANCE' : 'FLAT',
                                    style: TextStyle(
                                      fontFamily: 'UberMove',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDistanceBased
                                          ? Color(0xFF3B82F6)
                                          : Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pricing details
                        Row(
                          children: [
                            Expanded(
                              child: _buildPriceItem(
                                Icons.price_check,
                                'Base Price',
                                _formatPrice(rate['basePrice'] as double),
                              ),
                            ),
                            if (isDistanceBased) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildPriceItem(
                                  Icons.speed,
                                  'Per Km',
                                  _formatPrice(rate['pricePerKm'] as double),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Last updated
                        _buildPriceItem(
                          Icons.calendar_today_outlined,
                          'Last Updated',
                          _formatDate(rate['updatedAt']),
                        ),
                        const SizedBox(height: 16),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Edit button
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: GestureDetector(
                                onTap: () => _showEditDialog(rate),
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
                            const SizedBox(width: 8),

                            // Delete button
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: GestureDetector(
                                onTap: () => _showDeleteDialog(rate['id'], rate['serviceType']),
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

  /// Builds a price item row with icon, label and value
  Widget _buildPriceItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF64748B),
        ),
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
}

