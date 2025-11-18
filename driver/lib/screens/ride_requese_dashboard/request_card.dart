import 'package:flutter/material.dart';

class RequestCard extends StatefulWidget {
  final String requestId;
  final String pickupLocation;
  final String destination;
  final String distance;
  final String fare;
  final String estimatedTime;
  final double passengerRating;
  final String vehicleType;
  final VoidCallback onAccept;

  const RequestCard({
    Key? key,
    required this.requestId,
    required this.pickupLocation,
    required this.destination,
    required this.distance,
    required this.fare,
    required this.estimatedTime,
    required this.passengerRating,
    required this.vehicleType,
    required this.onAccept,
  }) : super(key: key);

  @override
  _RequestCardState createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;

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
                  _buildLocationInfo(),
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
                'PASSENGER',
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
              color: Colors.green,
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

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          _buildLocationRow(
            Icons.location_on,
            widget.pickupLocation,
            Colors.redAccent,
            'PICKUP',
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Container(width: 2, height: 16, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 1, color: Colors.grey)),
              ],
            ),
          ),
          _buildLocationRow(
            Icons.flag,
            widget.destination,
            Colors.black,
            'DESTINATION',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
      IconData icon,
      String location,
      Color color,
      String label,
      ) {
    return Row(
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
                location,
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
          _buildDetailItem(Icons.straighten, widget.distance, 'DISTANCE'),
          _buildDetailItem(Icons.schedule, widget.estimatedTime, 'DURATION'),
          _buildDetailItem(_getVehicleIcon(widget.vehicleType), _getVehicleDisplayName(widget.vehicleType), 'VEHICLE'),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.black, size: 12),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
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
    );
  }

  // Helper methods for vehicle type display
  IconData _getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
      case 'motorcycle':
      case 'two-wheeler':
        return Icons.two_wheeler;
      case 'car':
      case 'sedan':
      case 'four-wheeler':
        return Icons.directions_car;
      case 'truck':
      case 'heavy-truck':
      case 'heavy truck':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }

  String _getVehicleDisplayName(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
      case 'motorcycle':
      case 'two-wheeler':
        return 'BIKE';
      case 'car':
      case 'sedan':
      case 'four-wheeler':
        return 'CAR';
      case 'truck':
      case 'heavy-truck':
      case 'heavy truck':
        return 'TRUCK';
      default:
        return vehicleType.toUpperCase();
    }
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