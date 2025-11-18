import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:user/screens/home/home_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_util.dart';
import 'driver_tracking_screen.dart';

IO.Socket? globalSocket;

class FindingDriverScreen extends StatefulWidget {
  final Map<String, dynamic> serviceRequest;
  final Map<String, dynamic> routeData;

  const FindingDriverScreen({
    super.key,
    required this.serviceRequest,
    required this.routeData,
  });

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen> {
  final MapController _mapController = MapController();
  bool _driverAssigned = false;
  Map<String, dynamic>? _driverData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _initSocket();
  }

  void _initSocket() async {
    try {
      final token = await Auth.getToken();
      if (token == null) return;

      if (globalSocket == null) {
        globalSocket = IO.io(
          'https://smiling-sparrow-proper.ngrok-free.app',
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .setExtraHeaders({'Authorization': 'Bearer $token'})
              .build(),
        );

        globalSocket!.onConnect((_) {
          globalSocket!.emit('authenticate', token);
        });

        globalSocket!.on('authenticated', (data) {
          if (data['success'] == true) {
            globalSocket!.emit('join_request', {
              'serviceRequestId': widget.serviceRequest['_id'],
            });
          }
        });
      }

      globalSocket!.on('driver_assigned', (data) {
        if (mounted) {
          setState(() {
            _driverAssigned = true;
            _driverData = data['driver'];
          });
          _navigateToDriverTracking(data);
        }
      });

      globalSocket!.on('request_timeout', (data) {
        if (mounted) {
          _showTimeoutDialog();
        }
      });

      if (!globalSocket!.connected) {
        globalSocket!.connect();
      }

    } catch (e) {
    }
  }

  void _navigateToDriverTracking(Map<String, dynamic> data) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DriverTrackingScreen(
          driverData: data['driver'],
          serviceRequest: widget.serviceRequest,
          routeData: widget.routeData,
        ),
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'No Drivers Available',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Sorry, no drivers are currently available. Please try again later.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelServiceRequest();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelServiceRequest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final api = ApiService();
      final result = await api.cancelServiceRequest(widget.serviceRequest['_id']);

      if (result['success'] == true) {
        globalSocket?.emit('leave_request', {
          'serviceRequestId': widget.serviceRequest['_id'],
        });

        if (mounted) {
          SnackBarUtil.showSuccess(context, result['message']);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
          );
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (error) {
      if (mounted) {
        SnackBarUtil.showError(context, 'Error: ${error.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    globalSocket?.off('driver_assigned');
    globalSocket?.off('request_timeout');

    globalSocket?.emit('leave_request', {
      'serviceRequestId': widget.serviceRequest['_id'],
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final pickupLat = double.tryParse(
      widget.routeData['pickupLat']?.toString() ?? '',
    );
    final pickupLng = double.tryParse(
      widget.routeData['pickupLng']?.toString() ?? '',
    );
    final dropoffLat = double.tryParse(
      widget.routeData['dropoffLat']?.toString() ?? '',
    );
    final dropoffLng = double.tryParse(
      widget.routeData['dropoffLng']?.toString() ?? '',
    );

    List<LatLng> routePoints = [];

    if (pickupLat != null && pickupLng != null) {
      routePoints.add(LatLng(pickupLat, pickupLng));
    }
    if (dropoffLat != null && dropoffLng != null) {
      routePoints.add(LatLng(dropoffLat, dropoffLng));
    }

    final bounds = routePoints.isNotEmpty
        ? LatLngBounds.fromPoints(routePoints)
        : null;

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[900],
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCameraFit: bounds != null
                              ? CameraFit.bounds(
                            bounds: bounds,
                            padding: EdgeInsets.all(screenWidth * 0.2),
                          )
                              : null,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                          minZoom: 10,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: ['a', 'b', 'c'],
                          ),
                          if (widget.routeData.containsKey('routePoints') &&
                              (widget.routeData['routePoints'] as List)
                                  .isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points:
                                  (widget.routeData['routePoints'] as List)
                                      .map<LatLng>(
                                        (point) => LatLng(
                                      point['lat'],
                                      point['lng'],
                                    ),
                                  )
                                      .toList(),
                                  color: Colors.blue,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (pickupLat != null && pickupLng != null)
                                Marker(
                                  point: LatLng(pickupLat, pickupLng),
                                  width: screenWidth * 0.1,
                                  height: screenWidth * 0.1,
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: screenWidth * 0.1,
                                  ),
                                ),
                              if (dropoffLat != null && dropoffLng != null)
                                Marker(
                                  point: LatLng(dropoffLat, dropoffLng),
                                  width: screenWidth * 0.1,
                                  height: screenWidth * 0.1,
                                  child: Icon(
                                    Icons.pin_drop,
                                    color: Colors.blue,
                                    size: screenWidth * 0.1,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomPanel(screenWidth, screenHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(double screenWidth, double screenHeight) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_driverAssigned) ...[
            _buildDriverInfo(screenWidth),
            SizedBox(height: screenHeight * 0.02),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const Text(
                    'Finding a driver',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'UberMove',
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  SizedBox(
                    width: screenWidth * 0.8,
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.green,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
          ],

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.015,
              horizontal: screenWidth * 0.04,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Your final amount',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontFamily: 'UberMove',
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  '${widget.routeData['totalAmount']?.toStringAsFixed(1) ?? '0.0'} PKR',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'UberMove',
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.015,
              horizontal: screenWidth * 0.04,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: screenWidth * 0.05),
                    SizedBox(height: screenHeight * 0.014),
                    Icon(Icons.pin_drop, color: Colors.blue, size: screenWidth * 0.05),
                  ],
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.routeData['pickupLocation'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'UberMove',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        widget.routeData['destinationLocation'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'UberMove',
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

          SizedBox(height: screenHeight * 0.02),

          OutlinedButton(
            onPressed: _isLoading ? null : _showCancelDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.grey),
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(double.infinity, screenHeight * 0.06),
            ),
            child: _isLoading
                ? SizedBox(
              width: screenWidth * 0.05,
              height: screenWidth * 0.05,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Text(
              "Cancel Request",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
                fontFamily: 'UberMove',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.03,
        horizontal: screenWidth * 0.04,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: screenWidth * 0.07,
            backgroundImage: _driverData?['avatar'] != null
                ? NetworkImage(_driverData!['avatar'])
                : null,
            child: _driverData?['avatar'] == null
                ? Icon(Icons.person, size: screenWidth * 0.07, color: Colors.white)
                : null,
          ),
          SizedBox(height: screenWidth * 0.02),
          Text(
            _driverData?['name'] ?? 'Driver',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              fontFamily: 'UberMove',
            ),
          ),
          SizedBox(height: screenWidth * 0.01),
          Text(
            '${_driverData?['vehicle']?['model'] ?? 'Vehicle'} • ${_driverData?['vehicle']?['plate'] ?? 'Plate'}',
            style: TextStyle(
              color: Colors.grey,
              fontSize: screenWidth * 0.035,
              fontFamily: 'UberMove',
            ),
          ),
          SizedBox(height: screenWidth * 0.01),
          Text(
            'ETA: ${_driverData?['eta'] ?? '5'} minutes',
            style: TextStyle(
              color: Colors.green,
              fontSize: screenWidth * 0.035,
              fontFamily: 'UberMove',
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Cancel Service Request',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to cancel this service request?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'No',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelServiceRequest();
              },
              child: const Text(
                'Yes, Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}