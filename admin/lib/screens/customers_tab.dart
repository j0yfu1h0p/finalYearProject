import 'package:admin/auth_service.dart';
import 'package:admin/screens/login.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomersTab extends StatefulWidget {
  const CustomersTab({Key? key}) : super(key: key);

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _showSearch = false;
  String _error = '';

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

  Future<void> _searchCustomers() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _customers = [];
        _error = '';
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = '';
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _handleUnauthorized();
        return;
      }

      final queryParams = {
        'phoneNumber': _formatPhoneNumber(query),
        'limit': '20',
      };

      final uri = Uri.parse(
        'https://smiling-sparrow-proper.ngrok-free.app/api/admin/customers/search',
      ).replace(queryParameters: queryParams);

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
          _customers = (data as List)
              .map((e) => {
            'id': e['_id'],
            'fullName': e['fullName'] ?? 'Unknown',
            'mobile': e['phoneNumber'] ?? 'N/A',
          })
              .toList();
          _isLoading = false;
        });
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        throw Exception('Failed: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
        _customers = [];
      });

      if (e is! String || !e.contains('Navigator')) {
        SnackBarUtil.showError(context, 'Search failed: $e');
      }
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
          'Customer Management',
          style: TextStyle(
            fontFamily: 'UberMove',
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close : Icons.search,
              color: const Color(0xFF1E293B),
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _customers = [];
                  _error = '';
                  _hasSearched = false;
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          controller: _searchCtrl,
                          style: const TextStyle(
                            fontFamily: 'UberMove',
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search customer by phone number',
                            hintStyle: TextStyle(
                              fontFamily: 'UberMove',
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _searchCustomers(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward,
                            color: Color(0xFF10B981)),
                        onPressed: _searchCustomers,
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
          : (!_hasSearched
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search,
                size: 48, color: Color(0xFF64748B)),
            SizedBox(height: 16),
            Text(
              'Enter a phone number to search',
              style: TextStyle(
                fontFamily: 'UberMove',
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      )
          : _error.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error,
              style: const TextStyle(
                fontFamily: 'UberMove',
                fontSize: 16,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      )
          : _customers.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_search,
                size: 48, color: Color(0xFF64748B)),
            SizedBox(height: 16),
            Text(
              'No customers found',
              style: TextStyle(
                fontFamily: 'UberMove',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _searchCustomers,
        color: const Color(0xFF10B981),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: _customers.length,
          itemBuilder: (context, index) {
            final customer = _customers[index];
            return _buildCustomerCard(customer);
          },
        ),
      )),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
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
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer['fullName'],
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
                        'ID: ${customer['id']}',
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
            const SizedBox(height: 16),
            _buildDetailItem(
              Icons.phone_outlined,
              'Mobile',
              customer['mobile'],
            ),
          ],
        ),
      ),
    );
  }

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