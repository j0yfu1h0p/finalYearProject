// recent_bookings_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

import '../../services/api_services.dart';
import '../../utils/snackbar_util.dart';

class DriverBookingCard extends StatelessWidget {
  final String pickupLocation;
  final String dropLocation;
  final String date;
  final String status;
  final String vehicleType;
  final double amount;
  final String userphoneNumber;
  final String driverphoneNumber;
  final String bookingId;

  const DriverBookingCard({
    super.key,
    required this.pickupLocation,
    required this.dropLocation,
    required this.date,
    required this.status,
    required this.vehicleType,
    required this.amount,
    required this.userphoneNumber,
    required this.driverphoneNumber,
    required this.bookingId,
  });

  Color _getStatusColor() {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'pending':
        return Colors.grey;
      case 'confirmed':
      case 'accepted':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${bookingId.substring(0, 8)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: "UberMove",
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bookingId));
                    SnackBarUtil.showSuccess(context, 'Booking ID copied to clipboard');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Pickup location row
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickupLocation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: "UberMove",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Drop-off location row
            Row(
              children: [
                Icon(Icons.flag, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dropLocation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: "UberMove",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status and amount row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getStatusColor()),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w600,
                      fontFamily: "UberMove",
                    ),
                  ),
                ),
                Text(
                  'PKR ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: "UberMove",
                  ),
                ),
              ],
            ),

            // Mobile numbers row
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User: $userphoneNumber',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontFamily: "UberMove",
                  ),
                ),
                Text(
                  'Driver: ${driverphoneNumber.isNotEmpty ? driverphoneNumber : 'Not assigned'}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontFamily: "UberMove",
                  ),
                ),
              ],
            ),

            // Vehicle type and date row
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vehicleType,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontFamily: "UberMove",
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontFamily: "UberMove",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MechanicBookingCard extends StatefulWidget {
  final String serviceType;
  final String notes;
  final String date;
  final String status;
  final String userPhone;
  final String bookingId;
  final List<double> coordinates;
  final String mechanicPhone;

  const MechanicBookingCard({
    super.key,
    required this.serviceType,
    required this.notes,
    required this.date,
    required this.status,
    required this.userPhone,
    required this.bookingId,
    required this.coordinates,
    required this.mechanicPhone,
  });

  @override
  State<MechanicBookingCard> createState() => _MechanicBookingCardState();
}

class _MechanicBookingCardState extends State<MechanicBookingCard> {
  String _locationAddress = "Loading address...";
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _getAddressFromCoordinates();
  }

  Future<void> _getAddressFromCoordinates() async {
    if (widget.coordinates.length >= 2) {
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.coordinates[1], // latitude
          widget.coordinates[0], // longitude
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;
          setState(() {
            _locationAddress = "${place.street}, ${place.locality}, ${place.administrativeArea}";
            _isLoadingAddress = false;
          });
        } else {
          setState(() {
            _locationAddress = "Unknown location";
            _isLoadingAddress = false;
          });
        }
      } catch (e) {
        setState(() {
          _locationAddress = "Error loading address";
          _isLoadingAddress = false;
        });
      }
    } else {
      setState(() {
        _locationAddress = "No coordinates available";
        _isLoadingAddress = false;
      });
    }
  }

  Color _getStatusColor() {
    final normalized = widget.status.toLowerCase();
    switch (normalized) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${widget.bookingId.substring(0, 8)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: "UberMove",
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.bookingId));
                    SnackBarUtil.showSuccess(context, 'Booking ID copied to clipboard');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Service Type
            Row(
              children: [
                Icon(Icons.build, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.serviceType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: "UberMove",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location coordinates and address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coordinates: ${widget.coordinates[0]}, ${widget.coordinates[1]}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: "UberMove",
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _locationAddress,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontFamily: "UberMove",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Notes
            if (widget.notes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Notes:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                          fontFamily: "UberMove",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      widget.notes,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: "UberMove",
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

            // Status and date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getStatusColor()),
                  ),
                  child: Text(
                    widget.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: "UberMove",
                    ),
                  ),
                ),
                Text(
                  widget.date,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontFamily: "UberMove",
                  ),
                ),
              ],
            ),

            // User phone number
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Text(
                  'User: ${widget.userPhone}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontFamily: "UberMove",
                  ),
                ),
              ],
            ),

            // Mechanic phone number (if available)
            if (widget.mechanicPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Mechanic: ${widget.mechanicPhone}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontFamily: "UberMove",
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RecentBookingsPageScreen extends StatefulWidget {
  const RecentBookingsPageScreen({super.key});

  @override
  State<RecentBookingsPageScreen> createState() => _RecentBookingsPageScreenState();
}

class _RecentBookingsPageScreenState extends State<RecentBookingsPageScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _driverBookings = [];
  List<Map<String, dynamic>> _mechanicBookings = [];
  bool _isLoading = true;
  String? _error;
  final ApiService _apiService = ApiService();

  String? _driverStatus;
  String? _mechanicStatus;

  late TabController _tabController;
  int _currentTabIndex = 0;
  List<String> _availableTabs = [];

  @override
  void initState() {
    super.initState();
    _loadStatusAndFetchBookings();
  }

  void _setupTabController() {
    _availableTabs = [];
    if (_driverStatus == 'approved') _availableTabs.add('Driver');
    if (_mechanicStatus == 'approved') _availableTabs.add('Mechanic');

    _tabController = TabController(
        length: _availableTabs.length,
        vsync: this,
        initialIndex: 0
    );

    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  Future<void> _loadStatusAndFetchBookings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverStatus = prefs.getString('driverStatus');
      _mechanicStatus = prefs.getString('mechanicStatus');
    });
    _setupTabController();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch driver bookings only if driver status is approved
      if (_driverStatus == 'approved') {
        final driverResponse = await ApiService.getRecentBooking();

        if (driverResponse.statusCode == 200) {
          final Map<String, dynamic> driverData = jsonDecode(driverResponse.body);

          if (driverData['success'] == true) {
            // Handle different response structures
            if (driverData['data'] != null) {
              if (driverData['data']['docs'] != null) {
                final List<dynamic> docs = driverData['data']['docs'];
                _driverBookings = docs.map((item) => item as Map<String, dynamic>).toList();
              } else if (driverData['data'] is List) {
                final List<dynamic> docs = driverData['data'];
                _driverBookings = docs.map((item) => item as Map<String, dynamic>).toList();
              } else if (driverData['data'] is Map) {
                _driverBookings = [driverData['data']];
              }
            } else if (driverData['bookings'] != null) {
              final List<dynamic> docs = driverData['bookings'];
              _driverBookings = docs.map((item) => item as Map<String, dynamic>).toList();
            }
          }
        }
      } else {
        _driverBookings = [];
      }

      // Fetch mechanic bookings only if mechanic status is approved
      if (_mechanicStatus == 'approved') {
        final mechanicResponse = await ApiService.getMechanicRecentBookings();

        if (mechanicResponse.statusCode == 200) {
          final Map<String, dynamic> mechanicData = jsonDecode(mechanicResponse.body);

          if (mechanicData['success'] == true && mechanicData['bookings'] != null) {
            _mechanicBookings = List<Map<String, dynamic>>.from(mechanicData['bookings']);
          }
        }
      } else {
        _mechanicBookings = [];
      }

      setState(() {
        _isLoading = false;
      });

    } on TimeoutException {
      setState(() {
        _error = 'Request timed out. Please check your connection.';
        _isLoading = false;
      });
    } on SocketException {
      setState(() {
        _error = 'No internet connection. Please check your network settings.';
        _isLoading = false;
      });
    } on HttpException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on FormatException {
      setState(() {
        _error = 'Invalid data format received from server.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().contains('No token')
            ? 'Session expired. Please log in again.'
            : 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no services are approved, show a message
    if (_availableTabs.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Recent Bookings',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontFamily: "UberMove",
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 48, color: Colors.orange[400]),
              const SizedBox(height: 12),
              Text(
                'No services approved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: "UberMove",
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete your registration to access this feature',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: "UberMove",
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Recent Bookings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: "UberMove",
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchBookings,
            tooltip: 'Refresh',
          ),
        ],
        bottom: _availableTabs.length > 1
            ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: _availableTabs.map((tab) => Tab(text: tab)).toList(),
        )
            : null,
      ),

      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: _fetchBookings,
        child: _availableTabs.length > 1
            ? TabBarView(
          controller: _tabController,
          children: _availableTabs.map((tab) {
            if (tab == 'Driver') return _buildDriverContent();
            if (tab == 'Mechanic') return _buildMechanicContent();
            return Container();
          }).toList(),
        )
            : _availableTabs[0] == 'Driver'
            ? _buildDriverContent()
            : _buildMechanicContent(),
      ),
    );
  }

  Widget _buildDriverContent() {
    if (_isLoading && (_currentTabIndex == 0 || _availableTabs.length == 1)) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_error != null && _driverBookings.isEmpty) {
      return _buildErrorWidget();
    }

    if (_driverBookings.isEmpty) {
      return _buildEmptyWidget('No driver bookings found');
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _driverBookings.length,
      itemBuilder: (context, index) {
        final booking = _driverBookings[index];

        return DriverBookingCard(
          pickupLocation: booking['pickupLocation']?['address'] ??
              booking['pickupAddress'] ??
              booking['pickup']?['address'] ??
              'Unknown location',
          dropLocation: booking['destination']?['address'] ??
              booking['dropoffAddress'] ??
              booking['dropoff']?['address'] ??
              'Unknown destination',
          date: _formatDate(booking['createdAt'] ?? booking['requestTime'] ?? booking['timestamp'] ?? ''),
          status: (booking['status']?.toString() ?? 'unknown').toLowerCase(),
          vehicleType: booking['vehicleType'] ?? booking['serviceType'] ?? booking['vehicle']?['type'] ?? 'Unknown',
          amount: double.tryParse(booking['totalAmount']?.toString() ??
              booking['fare']?.toString() ??
              booking['amount']?.toString() ?? '0') ?? 0.0,
          userphoneNumber: booking['userId']?['phoneNumber']?.toString() ??
              booking['customer']?['phoneNumber']?.toString() ??
              booking['user']?['phoneNumber']?.toString() ?? 'N/A',
          driverphoneNumber: booking['driverId']?['phoneNumber']?.toString() ??
              booking['driver']?['phoneNumber']?.toString() ?? '',
          bookingId: booking['_id']?.toString() ??
              booking['id']?.toString() ?? 'N/A',
        );
      },
    );
  }

  Widget _buildMechanicContent() {
    if (_isLoading && (_currentTabIndex == 1 || _availableTabs.length == 1)) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_error != null && _mechanicBookings.isEmpty) {
      return _buildErrorWidget();
    }

    if (_mechanicBookings.isEmpty) {
      return _buildEmptyWidget('No mechanic service requests found');
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _mechanicBookings.length,
      itemBuilder: (context, index) {
        final booking = _mechanicBookings[index];

        // Extract coordinates from userLocation
        List<double> coordinates = [];
        if (booking['userLocation'] != null &&
            booking['userLocation']['coordinates'] != null &&
            booking['userLocation']['coordinates'].length >= 2) {
          coordinates = List<double>.from(booking['userLocation']['coordinates']);
        }

        // Extract mechanic phone number
        String mechanicPhone = '';
        if (booking['mechanicId'] != null && booking['mechanicId']['phoneNumber'] != null) {
          mechanicPhone = booking['mechanicId']['phoneNumber'].toString();
        }

        return MechanicBookingCard(
          serviceType: booking['serviceType'] ?? 'Unknown Service',
          notes: booking['notes'] ?? '',
          date: _formatDate(booking['createdAt'] ?? ''),
          status: (booking['status']?.toString() ?? 'unknown').toLowerCase(),
          userPhone: booking['userId']?['phoneNumber']?.toString() ??
              booking['userId']?['_id']?.toString() ?? 'N/A',
          bookingId: booking['_id']?.toString() ?? 'N/A',
          coordinates: coordinates,
          mechanicPhone: mechanicPhone,
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: "UberMove",
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
            ),
            onPressed: _fetchBookings,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.black,
                fontFamily: "UberMove",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[700],
              fontFamily: "UberMove",
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
            ),
            onPressed: _fetchBookings,
            child: const Text(
              'Refresh',
              style: TextStyle(
                color: Colors.black,
                fontFamily: "UberMove",
              ),
            ),
          ),
        ],
      ),
    );
  }
}