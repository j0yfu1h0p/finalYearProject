import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MechanicRequestCard extends StatefulWidget {
  final String requestId;
  final String serviceType;
  final String notes;
  final double latitude;
  final double longitude;
  final String fare;
  final VoidCallback onAccept;

  const MechanicRequestCard({
    Key? key,
    required this.requestId,
    required this.serviceType,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.fare,
    required this.onAccept,
  }) : super(key: key);

  @override
  _MechanicRequestCardState createState() => _MechanicRequestCardState();
}

class _MechanicRequestCardState extends State<MechanicRequestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;
  String _locationName = "Loading location...";
  String _distance = "Calculating...";
  String _estimatedTime = "Calculating...";
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );
    _cardController.forward();

    // Get location name and distance
    _getLocationInfo();
  }

  Future<void> _getLocationInfo() async {
    try {
      // Get device location
      Position devicePosition = await _getCurrentLocation();

      // Calculate distance
      final Distance distance = Distance();
      double distanceInMeters = distance(
        LatLng(devicePosition.latitude, devicePosition.longitude),
        LatLng(widget.latitude, widget.longitude),
      );

      // Convert to kilometers
      double distanceInKm = distanceInMeters / 1000;

      // Estimate time based on distance (assuming average speed of 30 km/h)
      int estimatedMinutes = (distanceInKm / 30 * 60).round();

      // Get location name
      List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.latitude,
          widget.longitude
      );

      String address = "Unknown location";
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        if (place.street != null && place.street!.isNotEmpty) {
          address = place.street!;
          if (place.locality != null && place.locality!.isNotEmpty) {
            address += ", ${place.locality!}";
          }
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          address = place.locality!;
        } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          address = place.subAdministrativeArea!;
        }
      }

      setState(() {
        _locationName = address;
        _distance = "${distanceInKm.toStringAsFixed(1)} km";
        _estimatedTime = "${estimatedMinutes} min";
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationName = "Location unavailable";
        _distance = "Unknown";
        _estimatedTime = "Unknown";
        _isLoadingLocation = false;
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    // Get the current location
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        final double opacityValue = _cardAnimation.value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: _cardAnimation.value,
          child: Opacity(
            opacity: opacityValue,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildCardHeader(),
                  _buildServiceInfo(),
                  _buildTripDetails(),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.requestId,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'MECHANIC SERVICE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.fare,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.build,
            widget.serviceType,
            Colors.blue,
            'SERVICE TYPE',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.note,
            widget.notes.isNotEmpty ? widget.notes : "No notes provided",
            Colors.grey,
            'NOTES',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon,
      String text,
      Color color,
      String label,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem(Icons.location_on, _locationName, 'LOCATION'),
          _buildDetailItem(Icons.straighten, _distance, 'DISTANCE'),
          _buildDetailItem(Icons.schedule, _estimatedTime, 'EST. TIME'),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.black, size: 12),
          const SizedBox(height: 2),
          _isLoadingLocation
              ? const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onAccept,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'ACCEPT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}