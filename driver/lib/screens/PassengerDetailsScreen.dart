import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/driver_request_screen_model.dart';
import '../services/passenger_details_api.dart';
import '../services/review_service.dart';
import '../services/websocket_service.dart';
import '../utils/snackbar_util.dart';
import '../widgets/user_review_prompt_sheet.dart';
import 'ride_requese_dashboard/driver_requests_dashboard.dart';
import './trip_chat_screen.dart';

class SimplePassengerDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final SocketService socketService;

  const SimplePassengerDetailsScreen({
    Key? key,
    required this.request,
    required this.socketService,
  }) : super(key: key);

  @override
  _SimplePassengerDetailsScreenState createState() =>
      _SimplePassengerDetailsScreenState();
}

class _SimplePassengerDetailsScreenState
    extends State<SimplePassengerDetailsScreen> {
  bool _isLoading = false;
  late SocketService _socketService;
  StreamSubscription? _socketSubscription;
  StreamSubscription? _locationRequestSubscription;
  Timer? _locationTimer;
  bool _hasArrived = false;
  bool _tripStarted = false;
  bool _hasPromptedCustomerReview = false;
  Map<String, dynamic> _passengerDetails = {};
  LatLng? _driverLatLng;

  // -------------------------------------------------
  // Foreground service helpers
  // -------------------------------------------------
  Future<void> _startForegroundService() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Driver on the way',
      notificationText: 'Tap to return to the app',
      callback: foregroundCallback,
    );
  }

  @pragma('vm:entry-point')
  static void foregroundCallback() {
    // Keep-alive stub – nothing to do here
  }

  // -------------------------------------------------
  @override
  void initState() {
    super.initState();
    _socketService = widget.socketService;
    _setupSocketListeners();
    _startLocationUpdates();
    _requestLocationPermissions();
    _fetchPassengerDetails();
    _startForegroundService();

    // NEW: Restore UI state based on trip status
    _restoreTripState();

    // NEW: Join driver tracking on init
    _socketService.joinDriverTracking(widget.request.id);

    _socketService.locationStream.listen((data) {
      final lat = data['lat'] as double;
      final lng = data['lng'] as double;
      setState(() => _driverLatLng = LatLng(lat, lng));
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.stopService();
    _socketSubscription?.cancel();
    _locationRequestSubscription?.cancel();
    _stopLocationUpdates();
    super.dispose();
  }

  // -------------------------------------------------
  // API-related methods
  // -------------------------------------------------
  Future<void> _fetchPassengerDetails() async {
    try {
      final details = await ApiService.getUserDetails(widget.request.userId);
      setState(() => _passengerDetails = details);
    } catch (e) {
      SnackBarUtil.showError(context, 'Error: $e');
    }
  }

  Future<void> _markAsArrived() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.markAsArrived(widget.request.id);
      _socketService.notifyDriverArrived(widget.request.id);
      setState(() => _hasArrived = true);
      SnackBarUtil.showSuccess(context, 'Arrival marked!');
    } catch (e) {
      SnackBarUtil.showError(context, 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startTrip() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.startTrip(widget.request.id);
      _socketService.notifyTripStarted(widget.request.id);
      setState(() => _tripStarted = true);
      SnackBarUtil.showSuccess(context, 'Trip started!');
    } catch (e) {
      SnackBarUtil.showError(context, 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRide(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      await ApiService.completeRide(widget.request.id);
      if (!mounted) return;
      SnackBarUtil.showSuccess(context, 'Ride completed!');
      await _promptCustomerReviewAfterRide();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => RideRequestsDashboard()),
        (_) => false,
      );
    } catch (e) {
      SnackBarUtil.showError(context, 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRide(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.cancelRide(widget.request.id);
      SnackBarUtil.showSuccess(context, 'Ride cancelled');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => RideRequestsDashboard()),
        (_) => false,
      );
    } catch (e) {
      SnackBarUtil.showError(context, 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _promptCustomerReviewAfterRide() async {
    if (_hasPromptedCustomerReview || !mounted) return;
    _hasPromptedCustomerReview = true;

    await showUserReviewPromptSheet(
      context: context,
      title: 'How was the passenger?',
      subtitle: 'Share quick feedback to keep rides safe for everyone.',
      accentColor: Colors.black,
      submitLabel: 'Send feedback',
      onSubmit: (rating, comment) => ReviewService.submitUserReviewForRide(
        widget.request.id,
        rating,
        comment: comment,
      ),
    );
  }

  // -------------------------------------------------
  // Socket and location methods
  // -------------------------------------------------
  void notifyRideCancelled(String requestId, String userId) =>
      _socketService.notifyRideCancelled(requestId, userId);
  void notifyTripCompleted(String tripId) =>
      _socketService.notifyTripCompleted(tripId);

  void _setupSocketListeners() {
    _socketSubscription = _socketService.statusStream.listen((data) {
      if (data['requestId'] == widget.request.id &&
          (data['type'] == 'user_cancelled_ride' ||
              data['message']?.contains('cancelled') == true)) {
        final msg = data['message'] ?? 'Ride cancelled by passenger';
        SnackBarUtil.showWarning(context, msg);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => RideRequestsDashboard()),
          (_) => false,
        );
      }
    });
    _locationRequestSubscription = _socketService.locationRequestStream.listen(
      (_) => _sendCurrentLocation(),
    );
  }

  Future<void> _requestLocationPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {}
  }

  void _startLocationUpdates() {
    _socketService.startLocationUpdates();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendCurrentLocation();
    });
  }

  void _stopLocationUpdates() {
    _socketService.stopLocationUpdates();
    _locationTimer?.cancel();
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      setState(() {
        _driverLatLng = LatLng(pos.latitude, pos.longitude);
      });
      _socketService.sendLocationUpdate({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'heading': pos.heading,
        'speed': pos.speed,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {}
  }

  // -------------------------------------------------
  // Sharing methods
  // -------------------------------------------------
  Future<void> _openInGoogleMaps() async {
    final destination = widget.request.destination.coordinates;
    final pickup = widget.request.pickupLocation.coordinates;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${pickup.lat},${pickup.lng}'
      '&destination=${destination.lat},${destination.lng}'
      '&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        SnackBarUtil.showError(context, 'Could not open Google Maps');
      }
    } catch (e) {
      SnackBarUtil.showError(context, 'Could not open Google Maps');
    }
  }

  // NEW: Add method to restore trip state after crash
  Future<void> _restoreTripState() async {
    try {
      final currentStatus = widget.request.status;
      if (currentStatus == 'arrived') {
        setState(() => _hasArrived = true);
      } else if (currentStatus == 'in_progress') {
        setState(() {
          _hasArrived = true;
          _tripStarted = true;
        });
      }
    } catch (e) {}
  }

  Future<void> _refreshPassengerDetails() async {
    setState(() => _isLoading = true);
    try {
      await _fetchPassengerDetails();
      SnackBarUtil.showSuccess(context, 'Passenger details refreshed');
    } catch (e) {
      SnackBarUtil.showError(context, 'Failed to refresh: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Ride Request',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'UberMove',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh passenger details',
            onPressed: _refreshPassengerDetails,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Trip Chat',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TripChatScreen(
                    tripId: widget.request.id,
                    tripModel: 'ServiceRequest',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildMainCard(context),
              const SizedBox(height: 20),
              _buildActionButtons(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          _buildMapSection(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1),
          ),
          _buildPassengerSection(context),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1),
          ),
          _buildRideDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final pickup = LatLng(
      widget.request.pickupLocation.coordinates.lat,
      widget.request.pickupLocation.coordinates.lng,
    );
    final dest = LatLng(
      widget.request.destination.coordinates.lat,
      widget.request.destination.coordinates.lng,
    );

    final bounds = LatLngBounds.fromPoints([pickup, dest]);
    final center = bounds.center;
    final zoom = _calculateZoom(bounds);

    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(center: center, zoom: zoom),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: pickup,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              Marker(
                point: dest,
                width: 40,
                height: 40,
                child: const Icon(Icons.flag, color: Colors.black, size: 32),
              ),
              if (_driverLatLng != null)
                Marker(
                  point: _driverLatLng!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.blueAccent,
                    size: 32,
                  ),
                ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [pickup, dest],
                strokeWidth: 4,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateZoom(LatLngBounds bounds) {
    const world = 256.0;
    const padding = 0.1;
    final ne = bounds.northEast;
    final sw = bounds.southWest;
    final latF = (ne.latitude - sw.latitude).abs() / 180.0;
    final lngF = (ne.longitude - sw.longitude).abs() / 360.0;
    final latZ = (log(world / 256.0 / latF) / ln2) - padding;
    final lngZ = (log(world / 256.0 / lngF) / ln2) - padding;
    return (latZ < lngZ ? latZ : lngZ).clamp(0.0, 18.0);
  }

  Widget _buildPassengerSection(BuildContext context) {
    final passengerName = _passengerDetails['name'] ?? 'Passenger';
    final passengerPhone = _passengerDetails['phone'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.grey[200]!, Colors.grey[300]!],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.black54, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'UberMove',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  passengerPhone,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.phone,
                    color: Colors.black87,
                    size: 20,
                  ),
                  onPressed: () => launch('tel:$passengerPhone'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  tooltip: 'Open Google Maps',
                  icon: Image.asset(
                    'assets/images/google_maps_icon.png',
                    width: 30,
                    height: 30,
                  ),
                  onPressed: _openInGoogleMaps,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            title: 'Pickup Location',
            subtitle: widget.request.pickupLocation.address,
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            icon: Icons.flag,
            iconColor: Colors.black,
            title: 'Destination',
            subtitle: widget.request.destination.address,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoCard(
                'Time',
                '${widget.request.duration} min',
                Icons.access_time,
              ),
              _buildInfoCard(
                'Distance',
                '${widget.request.distance.toStringAsFixed(1)} km',
                Icons.directions_car,
              ),
              _buildInfoCard(
                'Fare',
                'Rs. ${widget.request.totalAmount.toStringAsFixed(0)}',
                Icons.payments,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontFamily: 'UberMove',
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (_tripStarted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 300,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _completeRide(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'COMPLETE RIDE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    } else if (_hasArrived) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 300,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _startTrip(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'START TRIP',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _markAsArrived(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ARRIVED',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _cancelRide(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
