import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:user/screens/home/home_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/api_service.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../utils/snackbar_util.dart';
import '../../utils/refresh_button_widget.dart';
import 'package:user/screens/trip_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class DriverTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> driverData;
  final Map<String, dynamic> serviceRequest;
  final Map<String, dynamic> routeData;

  const DriverTrackingScreen({
    super.key,
    required this.driverData,
    required this.serviceRequest,
    required this.routeData,
  });

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  bool _isLoading = false;
  String _tripStatus = 'accepted';
  Timer? _locationUpdateTimer;
  IO.Socket? _socket;
  bool _isDisposed = false;
  bool _isNavigating = false;
  LatLng? _liveDriverLocation;
  LatLngBounds? _routeBounds;
  Map<String, dynamic>? _driverProfile;
  bool _isFetchingProfile = false;
  bool _isInitialized = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSoundEnabled = true;

  OverlayEntry? _notificationOverlay;
  Timer? _notificationTimer;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamController<String> _statusStreamController = StreamController<String>.broadcast();

  final Map<String, Map<String, dynamic>> _statusConfig = {
    'accepted': {
      'title': 'Trip Accepted',
      'message': 'Your driver is on the way',
      'color': Colors.blue,
      'icon': Icons.check_circle,
    },
    'arrived': {
      'title': 'Driver Arrived',
      'message': 'Your driver has arrived at pickup location',
      'color': Colors.orange,
      'icon': Icons.location_on,
    },
    'started': {
      'title': 'Trip Started',
      'message': 'Your trip has begun',
      'color': Colors.green,
      'icon': Icons.play_arrow,
    },
    'completed': {
      'title': 'Trip Completed',
      'message': 'You have reached your destination',
      'color': Colors.green,
      'icon': Icons.flag,
    },
    'cancelled': {
      'title': 'Trip Cancelled',
      'message': 'Your trip has been cancelled',
      'color': Colors.red,
      'icon': Icons.cancel,
    },
  };

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

    _statusStreamController.stream.listen((status) {
      if (status == 'completed' || status == 'cancelled') {
        _navigateToHomeScreen();
      }
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _initializeScreen();
      }
    });
  }

  void _initializeScreen() {
    _setupSocketConnection();
    _fetchDriverProfile().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  Future<void> _fetchDriverProfile() async {
    if (_isFetchingProfile) return;

    setState(() {
      _isFetchingProfile = true;
    });

    try {
      final token = await Auth.getToken();
      if (token == null) throw Exception('User not authenticated');

      final driverId = widget.driverData['_id'] ?? widget.driverData['id'];

      if (driverId == null || driverId.toString().isEmpty) {
        throw Exception('Driver ID not found in driverData');
      }

      final uri = Uri.parse(
        "https://smiling-sparrow-proper.ngrok-free.app/api/driver/$driverId/profile",
      );

      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['profile'] != null) {
          final profile = data['profile'];

          final formattedProfile = {
            'personal_info': {
              'name': profile['personal_info']['name'] ?? 'Driver Name',
              'phone': profile['personal_info']['phone'] ?? '+923184201830',
              'avatar': profile['personal_info']['avatar'],
            },
            'vehicles': profile['vehicles'] != null && profile['vehicles'].isNotEmpty
                ? [{
              'plate': profile['vehicles'][0]['plate'] ?? 'N/A',
              'color': profile['vehicles'][0]['color'] ?? 'Black',
            }]
                : widget.driverData['vehicle'] != null
                ? [widget.driverData['vehicle']]
                : [{'plate': 'N/A', 'color': 'Black'}],
          };

          setState(() {
            _driverProfile = formattedProfile;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch driver profile');
        }
      } else {
        throw Exception('Failed to fetch driver profile: ${response.statusCode}');
      }
    } catch (error) {
      if (!_isDisposed && mounted) {
        setState(() {
          _driverProfile = {
            'personal_info': {
              'name': widget.driverData['name'] ?? 'Driver',
              'phone': widget.driverData['phone'] ?? '',
              'avatar': widget.driverData['avatar'],
            },
            'vehicles': widget.driverData['vehicle'] != null
                ? [widget.driverData['vehicle']]
                : [{'plate': 'N/A', 'color': 'Black'}],
          };
        });
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isFetchingProfile = false;
        });
      }
    }
  }

  void _setupSocketConnection() async {
    try {
      _socket = IO.io(
        'https://smiling-sparrow-proper.ngrok-free.app',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build(),
      );

      _socket?.onConnect((_) {
        _socket?.emit('join_driver_tracking', {
          'driverId': widget.driverData['_id'],
          'tripId': widget.serviceRequest['_id'],
        });
      });

      _socket?.on('driver_location_update', (data) {
        if (!_isDisposed && mounted) {
          final lat = data['location']['lat']?.toDouble();
          final lng = data['location']['lng']?.toDouble();
          if (lat != null && lng != null) {
            setState(() {
              _driverLocation = LatLng(lat, lng);
              _liveDriverLocation = LatLng(lat, lng);
            });

            _mapController.move(_driverLocation!, 15.0);
          }
        }
      });

      _socket?.on('driver_arrived', (data) {
        if (!_isDisposed && mounted) {
          setState(() {
            _tripStatus = 'arrived';
          });
          _showStatusNotification('arrived');
        }
      });

      _socket?.on('trip_started', (data) {
        if (!_isDisposed && mounted) {
          setState(() {
            _tripStatus = 'started';
          });
          _showStatusNotification('started');
        }
      });

      _socket?.on('ride_status_update', (data) {
        if (!_isDisposed && mounted) {
          final newStatus = data['status'];
          final oldStatus = _tripStatus;

          setState(() {
            _tripStatus = newStatus;
          });

          if (newStatus != oldStatus) {
            _showStatusNotification(newStatus);
          }

          if (newStatus == 'completed' || newStatus == 'cancelled') {
            _statusStreamController.add(newStatus);
          }
        }
      });

      _socket?.onDisconnect((_) {
        _socket?.connect();
      });

      _socket?.onReconnect((_) {
        _socket?.emit('join_driver_tracking', {
          'driverId': widget.driverData['_id'],
          'tripId': widget.serviceRequest['_id'],
        });
      });

      _socket?.connect();
    } catch (e) {
      SnackBarUtil.showError(context, 'Connection error: $e');
    }
  }

  void _showStatusNotification(String status) {
    final config = _statusConfig[status];
    if (config == null) return;

    _playNotificationSound(status);
    _showOverlayNotification(
      config['title'] as String,
      config['message'] as String,
      config['color'] as Color,
      config['icon'] as IconData,
    );
  }

  Future<void> _playNotificationSound(String status) async {
    if (!_isSoundEnabled) return;

    try {
      String soundAsset = 'sounds/alert.mp3';
      await _audioPlayer.play(AssetSource(soundAsset));
    } catch (e) {
      try {
        switch (status) {
          case 'arrived':
          case 'completed':
          case 'cancelled':
            SystemSound.play(SystemSoundType.alert);
            break;
          case 'started':
            SystemSound.play(SystemSoundType.click);
            break;
          default:
            SystemSound.play(SystemSoundType.click);
        }
      } catch (systemError) {
      }
    }
  }

  void _showOverlayNotification(String title, String message, Color color, IconData icon) {
    _hideOverlayNotification();

    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            offset: const Offset(0, 0),
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (direction) {
                _hideOverlayNotification();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontFamily: 'UberMove',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _hideOverlayNotification,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_notificationOverlay!);
    _notificationTimer = Timer(const Duration(seconds: 5), _hideOverlayNotification);
  }

  void _hideOverlayNotification() {
    _notificationTimer?.cancel();
    _notificationTimer = null;

    if (_notificationOverlay != null) {
      _notificationOverlay?.remove();
      _notificationOverlay = null;
    }
  }

  void _navigateToHomeScreen() {
    if (_isNavigating) return;

    _isNavigating = true;

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_isDisposed && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
      _isNavigating = false;
    });
  }

  Future<void> _cancelTrip() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final api = ApiService();
      final result = await api.cancelServiceRequest(widget.serviceRequest['_id']);

      if (result['success']) {
        _socket?.emit('user_cancelled_ride', {
          'requestId': widget.serviceRequest['_id'],
          'driverId': widget.driverData['_id']
        });

        if (!_isDisposed && mounted) {
          setState(() {
            _tripStatus = 'cancelled';
          });
          _showStatusNotification('cancelled');
          _statusStreamController.add('cancelled');
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (error) {
      if (!_isDisposed && mounted) {
        SnackBarUtil.showError(context, 'Error cancelling trip: ${error.toString()}');
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Trip'),
          content: const Text('Are you sure you want to cancel this trip?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelTrip();
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

  @override
  void dispose() {
    _isDisposed = true;
    _locationUpdateTimer?.cancel();
    _socket?.disconnect();
    _socket?.off('driver_location_update');
    _socket?.off('driver_arrived');
    _socket?.off('trip_started');
    _socket?.off('trip_completed');
    _socket?.off('ride_cancelled_by_driver');
    _socket?.off('ride_status_update');
    _statusStreamController.close();
    _audioPlayer.dispose();
    _hideOverlayNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Loading driver information...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pickupLat = double.tryParse(widget.routeData['pickupLat']?.toString() ?? '');
    final pickupLng = double.tryParse(widget.routeData['pickupLng']?.toString() ?? '');
    final dropoffLat = double.tryParse(widget.routeData['dropoffLat']?.toString() ?? '');
    final dropoffLng = double.tryParse(widget.routeData['dropoffLng']?.toString() ?? '');

    List<LatLng> routePoints = [];
    if (pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null) {
      final pickup = LatLng(pickupLat, pickupLng);
      final drop   = LatLng(dropoffLat, dropoffLng);
      routePoints.addAll([pickup, drop]);
      _routeBounds = LatLngBounds.fromPoints([pickup, drop, if (_liveDriverLocation != null) _liveDriverLocation!]);
    }

    return WillPopScope(
      onWillPop: () async {
        if (_tripStatus == 'completed' || _tripStatus == 'cancelled') {
          return true;
        }

        bool shouldExit = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Trip?'),
            content: const Text('Are you sure you want to cancel this trip and go back?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ?? false;

        if (shouldExit) {
          _cancelTrip();
        }

        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
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
                  color: Colors.grey[200],
                  child: Stack(
                    children: [
                      FlutterMap(
                        key: ValueKey(_driverLocation?.toString()),
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(33.6495, 72.9767),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: 'com.example.user',
                          ),
                          if (routePoints.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
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
                              Marker(
                                point: _driverLocation ?? const LatLng(0, 0),
                                width: screenWidth * 0.1,
                                height: screenWidth * 0.1,
                                child: _driverLocation == null
                                    ? const SizedBox()
                                    : Icon(Icons.directions_car,
                                    color: Colors.green, size: screenWidth * 0.1),
                              ),
                              if (_liveDriverLocation != null)
                                Marker(
                                  point: _liveDriverLocation!,
                                  width: screenWidth * 0.12,
                                  height: screenWidth * 0.12,
                                  child: Icon(Icons.directions_car, color: Colors.green, size: screenWidth * 0.12),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: screenHeight * 0.02,
                        left: screenWidth * 0.04,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: Colors.black, size: screenWidth * 0.06),
                              onPressed: () {
                                if (_tripStatus == 'completed' || _tripStatus == 'cancelled') {
                                  _navigateToHomeScreen();
                                } else {
                                  _showCancelDialog();
                                }
                              },
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: RefreshButtonWidget(
                                onRefresh: () {
                                  _fetchDriverProfile();
                                  SnackBarUtil.showSuccess(context, 'Refreshing driver information...');
                                },
                                iconColor: Colors.black,
                                iconSize: screenWidth * 0.06,
                                tooltip: 'Refresh driver info',
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        bottom: screenHeight * 0.02,
                        right: screenWidth * 0.04,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter',
                          backgroundColor: Colors.white,
                          onPressed: () {
                            if (_routeBounds != null) {
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: _routeBounds!,
                                  padding: EdgeInsets.all(screenWidth * 0.1),
                                ),
                              );
                            }
                          },
                          child: Icon(Icons.my_location, color: Colors.black, size: screenWidth * 0.05),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildDriverDetailsPanel(screenWidth, screenHeight),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final id = widget.serviceRequest['_id']?.toString() ?? '';
            if (id.isEmpty) {
              SnackBarUtil.showWarning(context, 'Trip ID not available');
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripChatScreen(
                  tripId: id,
                  tripModel: 'ServiceRequest',
                ),
              ),
            );
          },
          child: const Icon(Icons.chat_bubble_outline),
        ),
      ),
    );
  }

  Widget _buildDriverDetailsPanel(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Driver Details',
              style: TextStyle(
                color: Colors.black,
                fontSize: screenWidth * 0.05,
                fontWeight: FontWeight.bold,
                fontFamily: 'UberMove',
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                  _buildDriverInfoSection(screenWidth),
                  SizedBox(height: screenHeight * 0.02),
                  Container(height: 1, color: Colors.grey[300]),
                  SizedBox(height: screenHeight * 0.02),
                  _buildVehicleInfoSection(screenWidth),
                  SizedBox(height: screenHeight * 0.02),
                  _buildLocationInfoSection('Pickup Location', Icons.location_on, Colors.red,
                      widget.routeData['pickupLocation'] ?? 'Pickup location not available', screenWidth),
                  SizedBox(height: screenHeight * 0.02),
                  _buildLocationInfoSection('Destination', Icons.flag, Colors.blue,
                      widget.routeData['destinationLocation'] ?? 'Destination not available', screenWidth),
                  SizedBox(height: screenHeight * 0.02),
                  _buildTripStatusSection(screenWidth),
                ],
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          _buildActionButtons(screenWidth, screenHeight),
        ],
      ),
    );
  }

  Widget _buildDriverInfoSection(double screenWidth) {
    return Row(
      children: [
        CircleAvatar(
          radius: screenWidth * 0.07,
          backgroundColor: Colors.grey[300],
          backgroundImage: _driverProfile?['personal_info']?['avatar'] != null
              ? NetworkImage(_driverProfile!['personal_info']['avatar'])
              : null,
          child: _driverProfile?['personal_info']?['avatar'] == null
              ? Icon(Icons.person, size: screenWidth * 0.06, color: Colors.white)
              : null,
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _driverProfile?['personal_info']?['name'] ?? widget.driverData['name'] ?? 'Driver',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'UberMove',
                ),
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                _driverProfile?['personal_info']?['phone'] ?? widget.driverData['phone'] ?? 'Phone not available',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfoSection(double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.directions_car, color: Colors.green[700], size: screenWidth * 0.06),
        SizedBox(width: screenWidth * 0.03),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey,
                  fontFamily: 'UberMove',
                ),
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                '${_driverProfile?['vehicles']?[0]?['color'] ?? widget.driverData['vehicle']?['color'] ?? 'N/A'} • ${_driverProfile?['vehicles']?[0]?['plate'] ?? widget.driverData['vehicle']?['plate'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.black,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfoSection(String title, IconData icon, Color color, String content, double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: screenWidth * 0.06),
        SizedBox(width: screenWidth * 0.03),
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
                  fontSize: screenWidth * 0.04,
                  color: Colors.black,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripStatusSection(double screenWidth) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip Status',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey,
                  fontFamily: 'UberMove',
                ),
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                _tripStatus.toUpperCase(),
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(_tripStatus),
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
    if (_tripStatus != 'completed' && _tripStatus != 'cancelled') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _showCancelDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
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
              child: const Text('Cancel Trip'),
            ),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final phoneNumber = widget.driverData['phone'] ?? '';
                final url = 'tel:$phoneNumber';
                _launchUrl(url);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
              child: const Text('Call Driver'),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _navigateToHomeScreen,
          style: ElevatedButton.styleFrom(
            backgroundColor: _tripStatus == 'completed' ? Colors.green : Colors.red,
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
          child: Text(
            _tripStatus == 'completed' ? 'Return to Home' : 'Trip Cancelled',
          ),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.orange;
      case 'started':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $urlString');
    }
  }
}
