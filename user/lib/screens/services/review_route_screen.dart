import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user/screens/services/finding_driver_screen.dart';
import 'package:user/screens/services/vehicle_selection_screen.dart';
import '../../providers/review_route_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ReviewRouteScreen extends StatefulWidget {
  final String pickupLocation;
  final String? selectedVehicle;
  final String? destinationLocation;
  final double? distance;
  final double? duration;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const ReviewRouteScreen({
    super.key,
    required this.pickupLocation,
    this.selectedVehicle,
    this.destinationLocation,
    this.distance,
    this.duration,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  @override
  State<ReviewRouteScreen> createState() => _ReviewRouteScreenState();
}

class _ReviewRouteScreenState extends State<ReviewRouteScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();
  double? _calculatedPrice;
  bool _isCalculatingPrice = false;
  String? _priceError;
  bool _priceCalculationComplete = false;

  bool get _isInputFilled =>
      _pickupController.text.trim().isNotEmpty &&
          _destinationController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pickupController.text = widget.pickupLocation;
    _destinationController.text = widget.destinationLocation ?? '';
    _pickupController.addListener(_onInputChanged);
    _destinationController.addListener(_onInputChanged);
    _pickupFocus.addListener(_onFocusChange);
    _destinationFocus.addListener(_onFocusChange);

    _calculatePrice();
  }

  void _onInputChanged() => setState(() {});
  void _onFocusChange() => setState(() {});

  Future<void> _calculatePrice() async {
    if (widget.distance == null || widget.selectedVehicle == null) {
      setState(() {
        _priceCalculationComplete = true;
      });
      return;
    }

    setState(() {
      _isCalculatingPrice = true;
      _priceError = null;
      _priceCalculationComplete = false;
    });

    try {
      final distanceKm = widget.distance! / 1000;
      final serviceType = ApiService.vehicleTypeToServiceType(
        widget.selectedVehicle!,
      );

      final token = await Auth.getToken();

      final priceData = await ApiService.calculatePrice(
        serviceType,
        distanceKm,
        token!,
      );

      if (mounted) {
        setState(() {
          _calculatedPrice = priceData?['totalPrice']?.toDouble();
          _isCalculatingPrice = false;
          _priceCalculationComplete = true;

          if (_calculatedPrice == null) {
            _priceError = 'Could not calculate price';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalculatingPrice = false;
          _priceError = 'Error calculating price';
          _priceCalculationComplete = true;
        });
      }
    }
  }

  void _showErrorDialog(
      String title,
      String message, {
        bool isRetryable = false,
      }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          if (isRetryable)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createServiceRequest(context);
              },
              child: const Text('Retry', style: TextStyle(color: Colors.blue)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createServiceRequest(BuildContext context) async {
    final provider = Provider.of<ReviewRouteProvider>(context, listen: false);
    provider.startLoading();

    try {
      if (widget.pickupLatitude == null ||
          widget.pickupLongitude == null ||
          widget.destinationLatitude == null ||
          widget.destinationLongitude == null) {
        _showErrorDialog(
          'Invalid Location',
          'Please select valid pickup and destination.',
        );
        return;
      }
      if (widget.distance == null || widget.duration == null) {
        _showErrorDialog(
          'Missing Route Data',
          'Distance and duration are missing.',
        );
        return;
      }
      if (widget.destinationLocation == null ||
          widget.destinationLocation!.isEmpty) {
        _showErrorDialog('Missing Destination', 'Please select a destination.');
        return;
      }

      final distanceInKm = widget.distance! / 1000;
      final durationInMinutes = widget.duration! / 60;

      if (_calculatedPrice == null) {
        _showErrorDialog(
          'Price Error',
          'Unable to calculate fare. Please try again.',
        );
        return;
      }

      final totalAmount = _calculatedPrice!;

      final requestData = {
        'vehicleType': widget.selectedVehicle ?? 'Four Wheeler',
        'pickupLocation': {
          'address': widget.pickupLocation,
          'coordinates': {
            'lat': widget.pickupLatitude,
            'lng': widget.pickupLongitude,
          },
        },
        'destination': {
          'address': widget.destinationLocation!,
          'coordinates': {
            'lat': widget.destinationLatitude,
            'lng': widget.destinationLongitude,
          },
        },
        'distance': distanceInKm,
        'duration': durationInMinutes,
        'rate': 500,
        'totalAmount': totalAmount,
      };

      final api = ApiService();
      final result = await api.createServiceRequest(requestData);

      provider.stopLoading();

      if (!mounted) return;

      if (result['success']) {
        final serviceRequestData = result['data'];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FindingDriverScreen(
              routeData: {
                'serviceRequestId': serviceRequestData['_id'],
                'vehicleType': serviceRequestData['vehicleType'],
                'pickupLocation': widget.pickupLocation,
                'destinationLocation': widget.destinationLocation,
                'selectedVehicle': widget.selectedVehicle,
                'pickupLat': widget.pickupLatitude,
                'pickupLng': widget.pickupLongitude,
                'dropoffLat': widget.destinationLatitude,
                'dropoffLng': widget.destinationLongitude,
                'distance': widget.distance! / 1000,
                'duration': widget.duration! / 60,
                'rate': 500,
                'totalAmount': totalAmount,
                'status': serviceRequestData['status'],
                'createdAt': serviceRequestData['createdAt'],
                'updatedAt': serviceRequestData['updatedAt'],
                'routePoints': [
                  {'lat': widget.pickupLatitude, 'lng': widget.pickupLongitude},
                  {
                    'lat': widget.destinationLatitude,
                    'lng': widget.destinationLongitude,
                  },
                ],
              },
              serviceRequest: serviceRequestData,
            ),
          ),
        );
      } else {
        if (result['status'] == 401 || result['status'] == 403) {
          Navigator.pushReplacementNamed(context, 'ContinueWithPhone');
        }
        _showErrorDialog(
          'Error',
          result['message'] ?? 'Something went wrong',
          isRetryable: true,
        );
      }
    } catch (e) {
      provider.stopLoading();
      _showErrorDialog('Unexpected Error', e.toString(), isRetryable: true);
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    return ChangeNotifierProvider(
      create: (context) => ReviewRouteProvider(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(screenWidth),
                SizedBox(height: screenHeight * 0.02),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildRouteDetailsCard(screenWidth, screenHeight),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(screenWidth, screenHeight),
                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(double screenWidth) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: screenWidth * 0.06,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        SizedBox(width: screenWidth * 0.03),
        Text(
          'Review Route Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            fontFamily: 'UberMove',
          ),
        ),
      ],
    );
  }

  Widget _buildRouteDetailsCard(double screenWidth, double screenHeight) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailSection(
              'Vehicle Type',
              widget.selectedVehicle ?? 'No vehicle selected',
              isPrimary: true,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.02),
            Container(height: 1, color: Colors.grey[800]),
            SizedBox(height: screenHeight * 0.02),
            _buildDetailSection(
              'Pickup Location',
              widget.pickupLocation,
              isPrimary: false,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.02),
            _buildDetailSection(
              'Destination Location',
              widget.destinationLocation ?? 'No destination selected',
              isPrimary: false,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.02),
            _buildDetailSection(
              'Distance',
              widget.distance != null
                  ? '${(widget.distance! / 1000).toStringAsFixed(1)} km'
                  : 'N/A',
              isPrimary: false,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.02),
            _buildDetailSection(
              'Estimated Time',
              widget.duration != null
                  ? '${(widget.duration! / 60).toStringAsFixed(0)} min'
                  : 'N/A',
              isPrimary: false,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.02),
            _buildPriceSection(screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, {required bool isPrimary, required double screenWidth}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey,
                  fontFamily: 'UberMove',
                ),
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                content,
                style: TextStyle(
                  fontSize: isPrimary ? screenWidth * 0.045 : screenWidth * 0.04,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                  color: Colors.white,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection(double screenWidth) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Price',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey,
                  fontFamily: 'UberMove',
                ),
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                _isCalculatingPrice
                    ? 'Calculating...'
                    : _calculatedPrice != null
                    ? 'PKR ${_calculatedPrice!.toStringAsFixed(2)}'
                    : 'N/A',
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(double screenWidth, double screenHeight) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              textStyle: TextStyle(
                fontFamily: 'UberMove',
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          child: ElevatedButton(
            onPressed: _calculatedPrice != null && !_isCalculatingPrice
                ? () => _createServiceRequest(context)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _calculatedPrice != null && !_isCalculatingPrice
                  ? Colors.green
                  : Colors.grey,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              textStyle: TextStyle(
                fontFamily: 'UberMove',
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
            ),
            child: const Text('Confirm Request'),
          ),
        ),
      ],
    );
  }
}