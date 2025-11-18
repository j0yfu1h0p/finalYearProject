import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/mechanic_socket_service.dart';
import '../../services/api_services.dart';
import '../../utils/refresh_button_widget.dart';
import 'driver_requests_dashboard.dart';
import '../trip_chat_screen.dart';

class UserTrackScreenMech extends StatefulWidget {
  final Map<String, dynamic> mechanicData;
  final Map<String, dynamic> serviceRequest;
  final Map<String, dynamic> userData;

  const UserTrackScreenMech({
    super.key,
    required this.mechanicData,
    required this.serviceRequest,
    required this.userData,
  });

  @override
  State<UserTrackScreenMech> createState() => _UserTrackScreenMechState();
}

class _UserTrackScreenMechState extends State<UserTrackScreenMech> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  LatLng? _mechanicLocation;
  List<LatLng> _routePoints = [];
  bool _isLoading = false;
  String _serviceStatus = 'accepted';
  Timer? _locationUpdateTimer;
  bool _isDisposed = false;
  bool _isNavigating = false;
  LatLng? _liveUserLocation;
  Map<String, dynamic>? _userProfile;
  bool _isFetchingProfile = false;
  bool _isInitialized = false;
  StreamSubscription<Position>? _positionSubscription;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamController<String> _statusStreamController =
      StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();

    // Set initial UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Set up status stream listener
    _statusStreamController.stream.listen((status) {
      if (status == 'completed' || status == 'cancelled') {
        _navigateToHomeScreen();
      }
    });

    // Initialize the screen
    _initializeScreen();

    // Start location & socket listeners
    Future.microtask(() async {
      await _setupLocationTracking();
      await _initSocket();
    });
  }

  void _initializeScreen() {
    // Initialize service status from the widget data
    final initialStatus = widget.serviceRequest['status'];
    if (initialStatus != null) {
      _serviceStatus = initialStatus;
    }

    _fetchUserProfile().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  Future<void> _fetchUserProfile() async {
    if (_isFetchingProfile) return;

    setState(() {
      _isFetchingProfile = true;
    });

    try {
      // Extract user data from service request
      final userLocation = widget.serviceRequest['userLocation'] ?? {};
      final coordinates = userLocation['coordinates'] ?? [0, 0];

      // Get user ID from widget.userData
      final userId = widget.userData['_id']?.toString();

      Map<String, dynamic>? userData;

      if (userId != null && userId.isNotEmpty) {
        // Fetch user data from API
        final apiResponse = await ApiService.getUserById(userId);

        if (apiResponse['success'] == true) {
          userData = apiResponse['user'];
        } else {
          // Show error message to user
          if (!_isDisposed && mounted) {
            _showSnackBar(
              'Failed to load user details: ${apiResponse['message']}',
              Colors.orange,
            );
          }
        }
      }

      // Create user profile with fetched data or fallback to widget data
      final userProfile = {
        'personal_info': {
          'name': userData?['name'] ?? widget.userData['name'] ?? 'Customer',
          'phone':
              userData?['phone'] ?? widget.userData['phone'] ?? '+1234567890',
          'avatar': widget.userData['avatar'],
        },
        'service_type':
            widget.serviceRequest['serviceType'] ?? 'Vehicle Service',
        'price': widget.serviceRequest['priceQuote'] != null
            ? 'Rs. ${widget.serviceRequest['priceQuote']['amount']}'
            : 'To be determined',
        'notes':
            widget.serviceRequest['notes'] ?? 'Please provide service details',
        'eta': 'En route',
        'location': LatLng(
          coordinates[1]?.toDouble() ?? 0.0,
          coordinates[0]?.toDouble() ?? 0.0,
        ),
      };

      setState(() {
        _userProfile = userProfile;
        _userLocation = userProfile['location'];
      });

      _updateRoutePolyline();
    } catch (error) {
      if (!_isDisposed && mounted) {
        _showSnackBar('Failed to load user details', Colors.orange);

        // Fallback to widget data in case of error
        final userLocation = widget.serviceRequest['userLocation'] ?? {};
        final coordinates = userLocation['coordinates'] ?? [0, 0];

        final fallbackProfile = {
          'personal_info': {
            'name': widget.userData['name'] ?? 'Customer',
            'phone': widget.userData['phone'] ?? '+1234567890',
            'avatar': widget.userData['avatar'],
          },
          'service_type':
              widget.serviceRequest['serviceType'] ?? 'Vehicle Service',
          'price': widget.serviceRequest['priceQuote'] != null
              ? 'Rs. ${widget.serviceRequest['priceQuote']['amount']}'
              : 'To be determined',
          'notes':
              widget.serviceRequest['notes'] ??
              'Please provide service details',
          'eta': 'En route',
          'location': LatLng(
            coordinates[1]?.toDouble() ?? 0.0,
            coordinates[0]?.toDouble() ?? 0.0,
          ),
        };

        setState(() {
          _userProfile = fallbackProfile;
          _userLocation = fallbackProfile['location'];
        });

        _updateRoutePolyline();
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isFetchingProfile = false;
        });
      }
    }
  }

  Future<void> _setupLocationTracking() async {
    if (_isDisposed) return;

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission || _isDisposed) return;

    await _updateMechanicLocation();

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) {
          if (!_isDisposed && mounted) {
            _onMechanicPosition(position);
          }
        }, onError: (_) {});
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showSnackBar(
          'Enable location services to share your live position',
          Colors.orange,
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showSnackBar(
          'Location permission is required to display your route',
          Colors.red,
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _updateMechanicLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _onMechanicPosition(position);
    } catch (e) {}
  }

  void _onMechanicPosition(Position position) {
    final location = LatLng(position.latitude, position.longitude);

    setState(() {
      _mechanicLocation = location;
    });

    _updateRoutePolyline();
  }

  void _updateRoutePolyline() {
    final mechanic = _mechanicLocation;
    final customer = _liveUserLocation ?? _userLocation;

    if (mechanic == null || customer == null) {
      if (_routePoints.isNotEmpty) {
        setState(() {
          _routePoints = [];
        });
      }
      return;
    }

    final bounds = LatLngBounds.fromPoints([mechanic, customer]);

    setState(() {
      _routePoints = [mechanic, customer];
    });

    _moveCameraToBounds(bounds);
  }

  void _moveCameraToBounds(LatLngBounds bounds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !mounted) return;

      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
        );
      } catch (e) {}
    });
  }

  Future<void> _initSocket() async {
    try {
      final mechanicId =
          (widget.mechanicData['_id'] ?? widget.mechanicData['id'])?.toString();
      final requestId =
          (widget.serviceRequest['_id'] ?? widget.serviceRequest['id'])
              ?.toString();

      if (mechanicId != null) {
        await MechanicSocketService.initializeSocket(mechanicId);
      } else {
        return;
      }

      if (requestId != null) {
        // Join the tracking room for this service request
        MechanicSocketService.joinMechanicTracking(mechanicId, requestId);

        // Start sending location updates
        _startLocationUpdates(mechanicId);
      }

      // Show current status notification after recovering
      if ((_serviceStatus == 'arrived' || _serviceStatus == 'in-progress') &&
          mounted &&
          !_isDisposed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _showStatusSnackBar(
              'Service Status: ${_serviceStatus.toUpperCase()}',
              _getStatusColor(_serviceStatus),
            );
          }
        });
      }

      // Listen for server instruction to rejoin tracking rooms
      MechanicSocketService.socket?.on('rejoin_job_tracking', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};
          final rejoinRequestId = map['requestId']?.toString();

          if (rejoinRequestId != null) {
            MechanicSocketService.joinMechanicTracking(
              mechanicId,
              rejoinRequestId,
            );

            // Also join the request room for trip chat
            MechanicSocketService.joinRequestRoom(rejoinRequestId);
          }
        } catch (e) {}
      });

      // Listen for user location updates
      MechanicSocketService.socket?.on('user_location_update', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};
          final loc = map['location'] is Map
              ? Map<String, dynamic>.from(map['location'])
              : {};
          final lat = double.tryParse(loc['lat']?.toString() ?? '');
          final lng = double.tryParse(loc['lng']?.toString() ?? '');

          if (lat != null && lng != null && mounted && !_isDisposed) {
            setState(() {
              _liveUserLocation = LatLng(lat, lng);
              _userLocation ??= _liveUserLocation;
            });

            _updateRoutePolyline();
          }
        } catch (e) {}
      });

      // Listen for service status updates
      MechanicSocketService.socket?.on('mechanic_status_update', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};
          final status = map['status']?.toString();
          if (status != null && mounted && !_isDisposed) {
            setState(() => _serviceStatus = status);
            _statusStreamController.add(status);
          }
        } catch (e) {}
      });

      // Listen for mechanic_request_update events
      MechanicSocketService.socket?.on('mechanic_request_update', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};

          // Update status if provided
          final status = map['status']?.toString();
          if (status != null && mounted && !_isDisposed) {
            final oldStatus = _serviceStatus;
            setState(() => _serviceStatus = status);
            _statusStreamController.add(status);

            // Show notification when status changes
            if (status != oldStatus) {
              _showStatusSnackBar(
                'Service Status: ${status.toUpperCase()}',
                _getStatusColor(status),
              );
            }
          }
        } catch (e) {}
      });

      // Listen for service completion
      MechanicSocketService.socket?.on('service_completed', (data) {
        if (mounted && !_isDisposed) {
          setState(() => _serviceStatus = 'completed');
          _statusStreamController.add('completed');
        }
      });

      // Listen for service cancellation
      MechanicSocketService.socket?.on('service_cancelled', (data) {
        if (mounted && !_isDisposed) {
          setState(() => _serviceStatus = 'cancelled');
          _statusStreamController.add('cancelled');
          _showSnackBar('Service has been cancelled', Colors.orange);
        }
      });
    } catch (e) {}
  }

  void _startLocationUpdates(String mechanicId) {
    // Send initial location
    _sendMechanicLocation(mechanicId);

    // Set up periodic location updates
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (!_isDisposed) {
        _sendMechanicLocation(mechanicId);
      }
    });
  }

  void _sendMechanicLocation(String mechanicId) async {
    try {
      LatLng? location = _mechanicLocation;

      if (location == null) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
        location = LatLng(position.latitude, position.longitude);

        if (!_isDisposed && mounted) {
          setState(() => _mechanicLocation = location);
          _updateRoutePolyline();
        }
      }

      MechanicSocketService.sendLocationUpdate(mechanicId, {
        'lat': location.latitude,
        'lng': location.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {}
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openNavigationInGoogleMaps() async {
    final origin = _mechanicLocation;
    final destination = _liveUserLocation ?? _userLocation;

    if (origin == null || destination == null) {
      _showSnackBar(
        'Waiting for both locations before opening Google Maps',
        Colors.orange,
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnackBar('Could not launch Google Maps', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to open Google Maps', Colors.red);
      }
    }
  }

  Widget _buildGoogleMapsBadge() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: ClipOval(
        child: Image.asset(
          'assets/images/google_maps_icon.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _navigateToHomeScreen() {
    if (_isNavigating) return;

    _isNavigating = true;

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_isDisposed && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const RideRequestsDashboard(),
          ),
          (route) => false,
        );
      }
      _isNavigating = false;
    });
  }

  Future<void> _updateServiceStatus(String newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call to update service status
      await Future.delayed(const Duration(seconds: 1));

      if (!_isDisposed && mounted) {
        setState(() {
          _serviceStatus = newStatus;
        });
        _statusStreamController.add(newStatus);

        // Emit socket event for status update
        final requestId =
            (widget.serviceRequest['_id'] ?? widget.serviceRequest['id'])
                ?.toString();
        if (requestId != null) {
          if (newStatus == 'arrived') {
            MechanicSocketService.emitMechanicArrived(requestId);
          } else if (newStatus == 'in-progress') {
            MechanicSocketService.emitMechanicJobStarted(requestId);
          } else if (newStatus == 'completed') {
            final mechanicId =
                (widget.mechanicData['_id'] ?? widget.mechanicData['id'])
                    ?.toString();
            if (mechanicId != null) {
              MechanicSocketService.emitMechanicJobCompleted(
                requestId,
                mechanicId,
              );
            }
          }
        }

        _showSnackBar('Status updated to: $newStatus', Colors.green);
      }
    } catch (error) {
      if (!_isDisposed && mounted) {
        _showSnackBar('Error: ${error.toString()}', Colors.red);
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      if (!_isDisposed && mounted) {
        _showSnackBar('Service request cancelled', Colors.orange);
        setState(() {
          _serviceStatus = 'cancelled';
        });
        _statusStreamController.add('cancelled');

        // Emit cancellation event
        final requestId =
            (widget.serviceRequest['_id'] ?? widget.serviceRequest['id'])
                ?.toString();
        final userId = (widget.userData['_id'] ?? widget.userData['id'])
            ?.toString();
        if (requestId != null && userId != null) {
          MechanicSocketService.emitMechanicCancelledJob(requestId, userId);
        }
      }
    } catch (error) {
      if (!_isDisposed && mounted) {
        _showSnackBar('Error: ${error.toString()}', Colors.red);
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
          title: const Text('Cancel Service'),
          content: const Text(
            'Are you sure you want to cancel this service request?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelService();
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

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Service Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_serviceStatus == 'accepted')
                ListTile(
                  leading: Icon(Icons.directions_car, color: Colors.blue),
                  title: Text('Mark as Arrived'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateServiceStatus('arrived');
                  },
                ),
              if (_serviceStatus == 'arrived')
                ListTile(
                  leading: Icon(Icons.build, color: Colors.orange),
                  title: Text('Start Service'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateServiceStatus('in-progress');
                  },
                ),
              if (_serviceStatus == 'in-progress')
                ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Complete Service'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateServiceStatus('completed');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showStatusSnackBar(String message, Color color) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_getStatusIcon(_serviceStatus), color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'arrived':
        return Icons.location_on;
      case 'in-progress':
        return Icons.build;
      case 'completed':
        return Icons.flag;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationUpdateTimer?.cancel();
    _positionSubscription?.cancel();
    _statusStreamController.close();
    // Remove socket listeners
    MechanicSocketService.socket?.off('user_location_update');
    MechanicSocketService.socket?.off('mechanic_status_update');
    MechanicSocketService.socket?.off('service_completed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Show loading screen until initialization is complete
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading service information...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_serviceStatus == 'completed' || _serviceStatus == 'cancelled') {
          return true;
        }

        bool shouldExit =
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Service?'),
                content: const Text(
                  'Are you sure you want to cancel this service and go back?',
                ),
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
            ) ??
            false;

        if (shouldExit) {
          _cancelService();
        }

        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Tracking Service'),
          backgroundColor: Colors.black,
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Trip Chat',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripChatScreen(
                      tripId: widget.serviceRequest['_id'],
                      tripModel: 'MechanicServiceRequest',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Map container
              Container(
                height: screenHeight * 0.3,
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    Builder(
                      builder: (_) {
                        final targetLocation =
                            _liveUserLocation ?? _userLocation;
                        final initialCenter =
                            targetLocation ??
                            _mechanicLocation ??
                            LatLng(33.6495, 72.9767);

                        return FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: initialCenter,
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                              userAgentPackageName: 'com.example.mechanic',
                            ),
                            if (_routePoints.length >= 2)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routePoints,
                                    strokeWidth: 4,
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                            if (_mechanicLocation != null ||
                                targetLocation != null)
                              MarkerLayer(
                                markers: [
                                  if (targetLocation != null)
                                    Marker(
                                      point: targetLocation,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    ),
                                  if (_mechanicLocation != null)
                                    Marker(
                                      point: _mechanicLocation!,
                                      width: 36,
                                      height: 36,
                                      child: const Icon(
                                        Icons.engineering,
                                        color: Colors.blue,
                                        size: 32,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                if (_serviceStatus == 'completed' ||
                                    _serviceStatus == 'cancelled') {
                                  _navigateToHomeScreen();
                                } else {
                                  _showCancelDialog();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: RefreshButtonWidget(
                              onRefresh: () {
                                _fetchUserProfile();
                                _showSnackBar(
                                  'Refreshing customer information...',
                                  Colors.green,
                                );
                              },
                              iconColor: Colors.black,
                              iconSize: 24,
                              tooltip: 'Refresh customer info',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              iconSize: 40,
                              padding: const EdgeInsets.all(6),
                              icon: _buildGoogleMapsBadge(),
                              tooltip: 'Open Google Maps directions',
                              onPressed: _openNavigationInGoogleMaps,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // User details panel
              Expanded(child: _buildUserDetailsPanel()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserDetailsPanel() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

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
          const Center(
            child: Text(
              'Customer Details',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'UberMove',
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          Expanded(
            child: SingleChildScrollView(
              child: Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User information
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                _userProfile?['personal_info']?['avatar'] !=
                                    null
                                ? NetworkImage(
                                    _userProfile!['personal_info']['avatar'],
                                  )
                                : null,
                            child:
                                _userProfile?['personal_info']?['avatar'] ==
                                    null
                                ? const Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userProfile?['personal_info']?['name'] ??
                                      'Customer',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userProfile?['personal_info']?['phone'] ??
                                      '+1234567890',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Container(height: 1, color: Colors.grey[300]),
                      const SizedBox(height: 20),

                      // Service information
                      Row(
                        children: [
                          Icon(Icons.build, color: Colors.blue[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Service Type',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userProfile?['service_type'] ??
                                      'Vehicle Service',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Price
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            color: Colors.green[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estimated Price',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userProfile?['price'] ?? 'To be determined',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Notes
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, color: Colors.purple[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer Notes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userProfile?['notes'] ??
                                      'No additional notes',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Service status
                      Row(
                        children: [
                          Icon(
                            Icons.stairs,
                            color: _getStatusColor(_serviceStatus),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Service Status',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serviceStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(_serviceStatus),
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          if (_serviceStatus != 'completed' && _serviceStatus != 'cancelled')
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showStatusUpdateDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.018,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'UberMove',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    child: Text(
                      _serviceStatus == 'accepted'
                          ? 'Mark as Arrived'
                          : _serviceStatus == 'arrived'
                          ? 'Start Service'
                          : 'Complete Service',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Call user functionality
                          final phone =
                              _userProfile?['personal_info']?['phone'];
                          if (phone != null) {
                            // Implement phone call functionality
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.018,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'UberMove',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Call Customer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showCancelDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.018,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'UberMove',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (_serviceStatus == 'completed' || _serviceStatus == 'cancelled')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToHomeScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _serviceStatus == 'completed'
                      ? Colors.green
                      : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                  textStyle: const TextStyle(
                    fontFamily: 'UberMove',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: Text(
                  _serviceStatus == 'completed'
                      ? 'Return to Home'
                      : 'Service Cancelled',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.orange;
      case 'in-progress':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
