import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/snackbar_util.dart';

class BookingCard extends StatelessWidget {
  final String pickupLocation;
  final String dropLocation;
  final String date;
  final String status;
  final String vehicleType;
  final double amount;
  final String userphoneNumber;
  final String driverphoneNumber;
  final String bookingId;
  final bool isMechanic;

  const BookingCard({
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
    this.isMechanic = false,
  });

  /// Determines status color based on booking status
  Color _getStatusColor() {
    final normalizedStatus = status.toLowerCase();
    switch (normalizedStatus) {
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
            // Booking ID header with copy functionality
            _buildBookingHeader(context),
            const SizedBox(height: 8),

            // Service type indicator for mechanic bookings
            if (isMechanic) _buildMechanicServiceHeader(),

            // Location information section
            _buildLocationSection(),

            // Status and amount display
            _buildStatusAndAmountRow(),

            // Contact information with masked phone numbers
            _buildContactInformationSection(),

            // Service type and date footer
            _buildFooterSection(),
          ],
        ),
      ),
    );
  }

  /// Builds the booking ID header with copy functionality
  Widget _buildBookingHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${isMechanic ? 'Mechanic Service' : 'Booking'} #${_getShortenedId(bookingId)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontFamily: "UberMove",
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
          onPressed: () => _copyBookingIdToClipboard(context),
        ),
      ],
    );
  }

  /// Builds mechanic service type header
  Widget _buildMechanicServiceHeader() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.build, color: Colors.orange[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Mechanic Service',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
                fontFamily: "UberMove",
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Builds location information section
  Widget _buildLocationSection() {
    return Column(
      children: [
        _buildLocationRow(
          icon: Icons.location_on,
          text: pickupLocation,
        ),
        if (!isMechanic) ...[
          const SizedBox(height: 8),
          _buildLocationRow(
            icon: Icons.flag,
            text: dropLocation,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  /// Builds individual location row
  Widget _buildLocationRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: "UberMove",
            ),
          ),
        ),
      ],
    );
  }

  /// Builds status and amount display row
  Widget _buildStatusAndAmountRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getStatusColor()),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(),
              fontWeight: FontWeight.w600,
              fontFamily: "UberMove",
            ),
          ),
        ),
        // Amount display
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
    );
  }

  /// Builds contact information section with masked phone numbers
  Widget _buildContactInformationSection() {
    return Column(
      children: [
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
              isMechanic
                  ? 'Mechanic: ${driverphoneNumber.isNotEmpty ? driverphoneNumber : 'Not assigned'}'
                  : 'Driver: ${driverphoneNumber.isNotEmpty ? driverphoneNumber : 'Not assigned'}',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontFamily: "UberMove",
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds footer section with service type and date
  Widget _buildFooterSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMechanic ? 'Mechanic Service' : vehicleType,
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
    );
  }

  /// Copies booking ID to clipboard with user feedback
  void _copyBookingIdToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: bookingId));
    SnackBarUtil.showSuccess(context, '${isMechanic ? 'Service' : 'Booking'} ID copied to clipboard');
  }

  /// Shortens booking ID for display purposes
  String _getShortenedId(String fullId) {
    return fullId.length > 8 ? fullId.substring(0, 8) : fullId;
  }
}

class RecentBookingsPageScreen extends StatefulWidget {
  const RecentBookingsPageScreen({super.key});

  @override
  State<RecentBookingsPageScreen> createState() => _RecentBookingsPageScreenState();
}

class _RecentBookingsPageScreenState extends State<RecentBookingsPageScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _towingBookings = [];
  List<Map<String, dynamic>> _mechanicBookings = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _fetchAllBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initializes tab controller with proper listener
  void _initializeTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  /// Handles tab change events
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _errorMessage = null; // Clear error when switching tabs
      });
    }
  }

  /// Fetches all bookings data
  Future<void> _fetchAllBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _fetchTowingBookings(),
        _fetchMechanicBookings()
      ]);
    } catch (error) {
      _handleFetchError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Fetches towing bookings from API
  Future<void> _fetchTowingBookings() async {
    try {
      final response = await _apiService.getRecentBookingsUser();

      if (response.statusCode != 200) {
        throw HttpException(
            'Failed to load towing bookings: ${response.statusCode}',
            uri: Uri.parse(response.request?.url.toString() ?? '')
        );
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['data'] != null && responseData['data']['docs'] != null) {
        final List<dynamic> docs = responseData['data']['docs'];
        final List<Map<String, dynamic>> bookings = docs
            .whereType<Map<String, dynamic>>()
            .toList();

        if (mounted) {
          setState(() {
            _towingBookings = bookings;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _towingBookings = [];
          });
        }
      }
    } catch (error) {
      // Silently handle towing booking errors to allow mechanic bookings to load
      if (mounted) {
        setState(() {
          _towingBookings = [];
        });
      }
    }
  }

  /// Fetches mechanic service requests from API
  Future<void> _fetchMechanicBookings() async {
    try {
      final response = await _apiService.getMechanicServiceRequests();

      if (response.statusCode != 200) {
        throw HttpException(
            'Failed to load mechanic services: ${response.statusCode}',
            uri: Uri.parse(response.request?.url.toString() ?? '')
        );
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<Map<String, dynamic>> bookings = _parseMechanicBookings(responseData);

      if (mounted) {
        setState(() {
          _mechanicBookings = bookings;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _mechanicBookings = [];
          if (_currentTabIndex == 1) {
            _errorMessage = 'Unable to load mechanic services. Please try again.';
          }
        });
      }
    }
  }

  /// Parses mechanic bookings from API response with robust error handling
  List<Map<String, dynamic>> _parseMechanicBookings(Map<String, dynamic> data) {
    try {
      final List<Map<String, dynamic>> bookings = [];

      if (data['data'] != null) {
        if (data['data'] is List) {
          bookings.addAll((data['data'] as List).whereType<Map<String, dynamic>>());
        } else if (data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          if (dataMap['docs'] is List) {
            bookings.addAll((dataMap['docs'] as List).whereType<Map<String, dynamic>>());
          }
        }
      }

      return bookings;
    } catch (error) {
      return [];
    }
  }

  /// Handles fetch errors with appropriate user messaging
  void _handleFetchError(dynamic error) {
    if (mounted) {
      setState(() {
        _errorMessage = 'Unable to load bookings. Please check your connection.';
      });
    }
  }

  /// Formats date string for display
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Formats service type for display
  String _formatServiceType(String serviceType) {
    const serviceTypeMap = {
      'car_lockout_service': 'Car Lockout Service',
      'puncture_repair': 'Puncture Repair',
      'battery_jumpstart': 'Battery Jumpstart',
      'fuel_delivery': 'Fuel Delivery',
    };

    return serviceTypeMap[serviceType] ??
        serviceType.replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Recent Services',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: "UberMove",
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Towing'),
            Tab(text: 'Mechanic'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchAllBookings,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTowingContent(),
          _buildMechanicContent(),
        ],
      ),
    );
  }

  Widget _buildTowingContent() {
    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _fetchTowingBookings,
      child: _buildBookingsList(_towingBookings, false),
    );
  }

  Widget _buildMechanicContent() {
    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _fetchMechanicBookings,
      child: _buildBookingsList(_mechanicBookings, true),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings, bool isMechanic) {
    if (_isLoading && bookings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_errorMessage != null && isMechanic && bookings.isEmpty) {
      return _buildErrorState();
    }

    if (bookings.isEmpty) {
      return _buildEmptyState(isMechanic);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking, isMechanic);
      },
    );
  }

  /// Builds error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
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
            onPressed: _fetchMechanicBookings,
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

  /// Builds empty state widget
  Widget _buildEmptyState(bool isMechanic) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No ${isMechanic ? 'mechanic services' : 'bookings'} found',
            style: TextStyle(
              color: Colors.grey[700],
              fontFamily: "UberMove",
            ),
          ),
        ],
      ),
    );
  }

  /// Builds individual booking card
  Widget _buildBookingCard(Map<String, dynamic> booking, bool isMechanic) {
    if (isMechanic) {
      return BookingCard(
        pickupLocation: 'Service: ${_formatServiceType(booking['serviceType']?.toString() ?? 'Unknown service')}',
        dropLocation: '',
        date: _formatDate(booking['createdAt']?.toString() ?? ''),
        status: booking['status']?.toString().toLowerCase() ?? 'unknown',
        vehicleType: '',
        amount: double.tryParse(booking['priceQuote']?['amount']?.toString() ?? '0') ?? 0.0,
        userphoneNumber: booking['userId'] is Map
            ? (booking['userId']?['phoneNumber']?.toString() ?? 'N/A')
            : 'N/A',
        driverphoneNumber: booking['mechanicId'] is Map
            ? (booking['mechanicId']?['phoneNumber']?.toString() ?? '')
            : '',
        bookingId: booking['_id']?.toString() ?? 'N/A',
        isMechanic: true,
      );
    } else {
      return BookingCard(
        pickupLocation: booking['pickupLocation']?['address'] ?? 'Unknown location',
        dropLocation: booking['destination']?['address'] ?? 'Unknown destination',
        date: _formatDate(booking['createdAt'] ?? ''),
        status: booking['status']?.toString().toLowerCase() ?? 'unknown',
        vehicleType: booking['vehicleType'] ?? 'Unknown vehicle',
        amount: double.tryParse(booking['totalAmount']?.toString() ?? '0') ?? 0.0,
        userphoneNumber: booking['userId']?['phoneNumber']?.toString() ?? 'N/A',
        driverphoneNumber: booking['driverId']?['phoneNumber']?.toString() ?? '',
        bookingId: booking['_id']?.toString() ?? 'N/A',
      );
    }
  }
}
