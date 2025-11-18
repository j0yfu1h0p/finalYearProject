import 'package:driver/screens/ride_requese_dashboard/request_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../../models/driver_request_screen_model.dart';
import '../../providers/driver_requests_provider.dart';
import '../../utils/snackbar_util.dart';
import '../PassengerDetailsScreen.dart';

class NearbyDriverRequestsScreen extends StatefulWidget {
  final DriverRequestsProvider provider;

  const NearbyDriverRequestsScreen({super.key, required this.provider});

  @override
  State<NearbyDriverRequestsScreen> createState() => _NearbyDriverRequestsScreenState();
}

class _NearbyDriverRequestsScreenState extends State<NearbyDriverRequestsScreen> {
  Position? _currentPosition;
  bool _locationLoading = false;
  String _locationError = '';
  double _searchRadius = 10.0;
  bool _showRadiusSlider = false; // Control visibility of radius slider

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _locationLoading = true;
        _locationError = '';
      });

      // Check location permission
      final status = await Permission.location.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _locationError = 'Location permission denied';
          _locationLoading = false;
        });
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled';
          _locationLoading = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationLoading = false;
      });

      // Load nearby requests
      await _loadNearbyRequests();
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
        _locationLoading = false;
      });
    }
  }

  Future<void> _loadNearbyRequests() async {
    if (_currentPosition == null) return;

    await widget.provider.loadNearbyDriverRequests(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusKm: _searchRadius,
    );
  }

  void _handleRefresh() async {
    if (_currentPosition != null) {
      await _loadNearbyRequests();
    } else {
      await _getCurrentLocation();
    }
  }

  void _updateSearchRadius(double radius) {
    setState(() {
      _searchRadius = radius;
    });
    if (_currentPosition != null) {
      _loadNearbyRequests();
    }
  }

  void _toggleRadiusSlider() {
    setState(() {
      _showRadiusSlider = !_showRadiusSlider;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Compact Location Status Card
        _buildCompactLocationHeader(),

        // Requests List
        Expanded(
          child: _buildRequestsList(context),
        ),
      ],
    );
  }

  Widget _buildCompactLocationHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Location Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _currentPosition != null ? Colors.green[50] : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentPosition != null ? Icons.location_on : Icons.location_off,
              color: _currentPosition != null ? Colors.green : Colors.grey,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),

          // Status Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_locationLoading)
                  Text(
                    'Getting location...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  )
                else if (_locationError.isNotEmpty)
                  Text(
                    _locationError,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  )
                else if (_currentPosition != null)
                    Text(
                      'Searching within $_searchRadius km',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    )
                  else
                    Text(
                      'Location not available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            children: [
              // Radius Toggle Button
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: _showRadiusSlider ? Colors.black : Colors.grey,
                  size: 18,
                ),
                onPressed: _toggleRadiusSlider,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),

              // Refresh Button
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: Colors.grey,
                  size: 18,
                ),
                onPressed: _handleRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Optional: Hidden radius slider that appears when toggle is pressed
  Widget _buildRadiusSlider() {
    if (!_showRadiusSlider) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Radius: ${_searchRadius.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _searchRadius,
            min: 1.0,
            max: 50.0,
            divisions: 49,
            onChanged: _updateSearchRadius,
            activeColor: Colors.black,
            inactiveColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context) {
    final provider = widget.provider;

    // Add the radius slider to the column if it's visible
    if (_showRadiusSlider) {
      return Column(
        children: [
          _buildRadiusSlider(),
          const SizedBox(height: 4),
          Expanded(child: _buildRequestContent(provider)),
        ],
      );
    }

    return _buildRequestContent(provider);
  }

  Widget _buildRequestContent(DriverRequestsProvider provider) {
    if (_locationLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_locationError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            Text(
              'Location Required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Enable location to see nearby ride requests',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Enable Location'),
            ),
          ],
        ),
      );
    }

    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Error loading requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (provider.driverRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_taxi, color: Colors.grey[400], size: 64),
            const SizedBox(height: 16),
            Text(
              'No nearby requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Check back later or adjust your search radius',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: provider.driverRequests.length,
      itemBuilder: (context, index) {
        final request = provider.driverRequests[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 8),
          child: RequestCard(
            requestId: '#${request.id.substring(request.id.length - 6)}',
            pickupLocation: request.pickupLocation.address,
            destination: request.destination.address,
            distance: '${request.distance.toStringAsFixed(1)} km',
            fare: 'Rs. ${request.totalAmount.toStringAsFixed(0)}',
            estimatedTime: '${request.duration} min',
            passengerRating: 4.5,
            vehicleType: request.vehicleType,
            onAccept: () => _handleAcceptDriver(request, context),
          ),
        );
      },
    );
  }

  void _handleAcceptDriver(ServiceRequest request, BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      );

      await widget.provider.acceptDriverRequest(request.id);
      Navigator.pop(context);
      widget.provider.socketService.joinDriverTracking(request.id);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => SimplePassengerDetailsScreen(
            request: request,
            socketService: widget.provider.socketService,
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      Navigator.pop(context);
      SnackBarUtil.showError(context, 'Failed to accept request: $e');
    }
  }
}