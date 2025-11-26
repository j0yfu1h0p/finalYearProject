import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:user/screens/home/home_screen.dart';
import 'package:user/screens/trip_chat_screen.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import '../../../services/auth_service.dart';
import '../../../services/review_service.dart';
import '../../../utils/refresh_button_widget.dart';
import '../../../utils/snackbar_util.dart';
import '../../../widgets/review_prompt_sheet.dart';
import 'mechanic_socket_service.dart';

class MechanicTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> mechanicData;
  final Map<String, dynamic> serviceRequest;
  final Map<String, dynamic> routeData;

  const MechanicTrackingScreen({
    super.key,
    required this.mechanicData,
    required this.serviceRequest,
    required this.routeData,
  });

  @override
  State<MechanicTrackingScreen> createState() => _MechanicTrackingScreenState();
}

class _MechanicTrackingScreenState extends State<MechanicTrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  String _tripStatus = 'accepted';
  Timer? _locationUpdateTimer;
  bool _isDisposed = false;
  bool _isNavigating = false;
  LatLng? _liveDriverLocation;
  LatLngBounds? _routeBounds;
  Map<String, dynamic>? _driverProfile;
  bool _isInitialized = false;
  Map<String, dynamic>? _requestData;
  String _pickupAddress = 'Loading address...';
  bool _isFetchingAddress = false;
  final ReviewService _reviewService = ReviewService();
  bool _hasShownReviewPrompt = false;
  bool _hasSubmittedReview = false;
  String? _existingReviewId;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSoundEnabled = true;

  OverlayEntry? _notificationOverlay;
  Timer? _notificationTimer;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamController<String> _statusStreamController =
      StreamController<String>.broadcast();

  final Map<String, Map<String, dynamic>> _statusConfig = {
    'accepted': {
      'title': 'Service Accepted',
      'message': 'Your mechanic is on the way',
      'color': Colors.blue,
      'icon': Icons.check_circle,
    },
    'arrived': {
      'title': 'Mechanic Arrived',
      'message': 'Your mechanic has arrived at your location',
      'color': Colors.orange,
      'icon': Icons.location_on,
    },
    'started': {
      'title': 'Service Started',
      'message': 'Your vehicle service has begun',
      'color': Colors.green,
      'icon': Icons.play_arrow,
    },
    'completed': {
      'title': 'Service Completed',
      'message': 'Your vehicle service has been completed',
      'color': Colors.green,
      'icon': Icons.flag,
    },
    'cancelled': {
      'title': 'Service Cancelled',
      'message': 'Your service request has been cancelled',
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
      if (status == 'completed') {
        _handleMechanicCompleted();
      } else if (status == 'cancelled') {
        _navigateToHomeScreen();
      }
    });

    _initializeScreen();
  }

  void _initializeScreen() {
    _requestData = widget.serviceRequest;
    _existingReviewId = widget.serviceRequest['reviewId']?.toString();

    if (mounted) {
      setState(() {
        _driverProfile = _createDriverProfileFromMechanicData(
          widget.mechanicData,
        );
        _tripStatus = _requestData?['status'] ?? 'accepted';
        _isInitialized = true;
      });
    }

    _fetchAddressFromCoordinates();
    Future.delayed(const Duration(milliseconds: 100), _initSocket);
  }

  Future<void> _fetchAddressFromCoordinates() async {
    final userLocation = _requestData?['userLocation'];
    final coordinates = userLocation != null
        ? userLocation['coordinates']
        : null;

    if (coordinates is List && coordinates.length >= 2) {
      final lng = coordinates[0]?.toDouble();
      final lat = coordinates[1]?.toDouble();

      if (lat != null && lng != null) {
        setState(() {
          _isFetchingAddress = true;
        });

        try {
          final address = await _reverseGeocode(LatLng(lat, lng));
          if (mounted && !_isDisposed) {
            setState(() {
              _pickupAddress = address;
              _isFetchingAddress = false;
            });
          }
        } catch (e) {
          if (mounted && !_isDisposed) {
            setState(() {
              _pickupAddress = 'Unable to fetch address';
              _isFetchingAddress = false;
            });
          }
        }
      } else {
        setState(() {
          _pickupAddress = 'Invalid coordinates';
        });
      }
    } else {
      setState(() {
        _pickupAddress = 'No coordinates available';
      });
    }
  }

  Future<String> _reverseGeocode(LatLng location) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'YourAppName/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        final address = data['display_name'] ?? 'Unknown location';
        return address.toString();
      } else {
        throw Exception('Failed to fetch address: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _createDriverProfileFromMechanicData(
    Map<String, dynamic> mechanicData,
  ) {
    final profile = {
      'personal_info': {
        'name':
            mechanicData['name'] ??
            mechanicData['personName'] ??
            'Unknown Mechanic',
        'phone':
            mechanicData['phone'] ??
            mechanicData['phoneNumber'] ??
            '+1234567890',
        'avatar': mechanicData['personalPhotoUrl'],
      },
      'service_type': _requestData?['serviceType'] ?? 'Car Service',
      'coordinates': _pickupAddress,
      'price': _requestData?['priceQuote'] != null
          ? '${_requestData?['priceQuote']['amount'] ?? '75'} ${_requestData?['priceQuote']['currency'] ?? 'PKR'}'
          : '75 PKR',
      'notes':
          _requestData?['notes'] ??
          'Please have your vehicle ready for inspection',
      'eta': '15-20 mins',
    };

    return profile;
  }

  void _initSocket() async {
    try {
      if (MechanicSocketService.socket == null ||
          !(MechanicSocketService.socket?.connected ?? false)) {
        await MechanicSocketService.initializeSocket();
      }

      final mechanicId =
          (widget.mechanicData['_id'] ?? widget.mechanicData['id'])?.toString();
      final requestId = (_requestData?['_id'] ?? _requestData?['id'])
          ?.toString();

      if (mechanicId != null && requestId != null) {
        MechanicSocketService.joinMechanicTracking(mechanicId, requestId);
      }

      if ((_tripStatus == 'arrived' || _tripStatus == 'in-progress') &&
          mounted &&
          !_isDisposed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _showStatusNotification(_tripStatus);
          }
        });
      }

      final mechanicCoords = widget.mechanicData['location']?['coordinates'];
      if (mechanicCoords is List && mechanicCoords.length >= 2) {
        final lng = double.tryParse(mechanicCoords[0]?.toString() ?? '');
        final lat = double.tryParse(mechanicCoords[1]?.toString() ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _driverLocation = LatLng(lat, lng);
            _liveDriverLocation = _driverLocation;
          });
        }
      }

      MechanicSocketService.socket?.on('rejoin_mechanic_tracking', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};
          final rejoinRequestId = map['requestId']?.toString();
          final rejoinMechanicId = map['mechanicId']?.toString();

          if (rejoinRequestId != null && rejoinMechanicId != null) {
            MechanicSocketService.joinMechanicTracking(
              rejoinMechanicId,
              rejoinRequestId,
            );
          }
        } catch (e) {}
      });

      MechanicSocketService.socket?.on('mechanic_location_update', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};
          final loc = map['location'] is Map
              ? Map<String, dynamic>.from(map['location'])
              : {};
          final lat = double.tryParse(loc['lat']?.toString() ?? '');
          final lng = double.tryParse(loc['lng']?.toString() ?? '');

          if (lat != null && lng != null && mounted && !_isDisposed) {
            setState(() {
              _liveDriverLocation = LatLng(lat, lng);
              _driverLocation ??= _liveDriverLocation;
              if (_routeBounds != null) {
                _routeBounds = LatLngBounds.fromPoints([
                  _routeBounds!.southWest,
                  _routeBounds!.northEast,
                  _liveDriverLocation!,
                ]);
              }
            });
          }
        } catch (e) {}
      });

      MechanicSocketService.socket?.on('mechanic_status_update', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};
          final status = map['status']?.toString();
          final oldStatus = _tripStatus;

          if (status != null && mounted && !_isDisposed) {
            setState(() => _tripStatus = status);
            _statusStreamController.add(status);

            if (status != oldStatus) {
              _showStatusNotification(status);
            }
          }
        } catch (e) {}
      });

      MechanicSocketService.socket?.on('mechanic_request_update', (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : {};

          final status = map['status']?.toString();
          if (status != null && mounted && !_isDisposed) {
            final oldStatus = _tripStatus;
            setState(() => _tripStatus = status);
            _statusStreamController.add(status);

            if (status != oldStatus) {
              _showStatusNotification(status);
            }
          }

          if (map['requestData'] != null) {
            setState(() {
              _requestData = Map<String, dynamic>.from(map['requestData']);
            });
          }
        } catch (e) {}
      });
    } catch (e) {}
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
      } catch (systemError) {}
    }
  }

  void _showOverlayNotification(
    String title,
    String message,
    Color color,
    IconData icon,
  ) {
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
    _notificationTimer = Timer(
      const Duration(seconds: 5),
      _hideOverlayNotification,
    );
  }

  void _hideOverlayNotification() {
    _notificationTimer?.cancel();
    _notificationTimer = null;

    if (_notificationOverlay != null) {
      _notificationOverlay?.remove();
      _notificationOverlay = null;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (color == Colors.green) {
      SnackBarUtil.showSuccess(context, message);
    } else if (color == Colors.red) {
      SnackBarUtil.showError(context, message);
    } else if (color == Colors.blue) {
      SnackBarUtil.showInfo(context, message);
    } else if (color == Colors.orange) {
      SnackBarUtil.showWarning(context, message);
    } else {
      SnackBarUtil.showInfo(context, message);
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

  Future<void> _handleMechanicCompleted() async {
    if (_hasSubmittedReview || _existingReviewId != null) {
      _navigateToHomeScreen();
      return;
    }

    if (_hasShownReviewPrompt || _isDisposed || !mounted) {
      _navigateToHomeScreen();
      return;
    }

    _hasShownReviewPrompt = true;

    final mechanicName =
        widget.mechanicData['name'] ??
        widget.mechanicData['personName'] ??
        widget.mechanicData['shopName'] ??
        'Your mechanic';
    final mechanicLabel =
        widget.serviceRequest['serviceType'] ??
        widget.mechanicData['shopName'] ??
        'Mechanic';
    final avatarUrl = widget.mechanicData['personalPhotoUrl']?.toString();
    final requestId =
        widget.serviceRequest['_id']?.toString() ??
        widget.serviceRequest['id']?.toString();

    if (requestId == null) {
      SnackBarUtil.showError(context, 'Missing service information.');
      _navigateToHomeScreen();
      return;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ReviewPromptSheet(
          title: 'Rate your mechanic',
          subtitle:
              'Share quick feedback so we can keep trusted pros on standby.',
          subjectName: mechanicName,
          subjectRole: mechanicLabel is String ? mechanicLabel : 'Mechanic',
          avatarUrl: avatarUrl,
          accentColor: Colors.blueAccent,
          onSubmit: (rating, comment) async {
            await _reviewService.submitMechanicReview(
              requestId: requestId,
              rating: rating,
              comment: comment,
            );
            _existingReviewId = 'submitted';
            _hasSubmittedReview = true;
            if (mounted) {
              SnackBarUtil.showSuccess(
                context,
                'Thanks for reviewing your mechanic!',
              );
            }
          },
        );
      },
    );

    _navigateToHomeScreen();
  }

  Future<void> _cancelTrip() async {
    try {
      final requestId = (_requestData?['_id'] ?? _requestData?['id'])
          ?.toString();

      if (requestId == null) {
        throw Exception('Request ID not found');
      }

      final token = await Auth.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final dio = Dio();
      dio.options.headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await dio.patch(
        'https://smiling-sparrow-proper.ngrok-free.app/api/mechanic/requests/$requestId/cancel',
      );

      if (response.statusCode == 200) {
        if (!_isDisposed && mounted) {
          _showSnackBar('Service request cancelled', Colors.green);
          setState(() {
            _tripStatus = 'cancelled';
          });

          _showStatusNotification('cancelled');
          _statusStreamController.add('cancelled');

          final mechanicId =
              (widget.mechanicData['_id'] ?? widget.mechanicData['id'])
                  ?.toString();
          if (mechanicId != null) {
            MechanicSocketService.emitMechanicCancelledJob(
              requestId,
              mechanicId,
            );
          }
        }
      } else {
        throw Exception(
          'Failed to cancel service request: ${response.statusCode}',
        );
      }
    } on DioException catch (dioError) {
      String errorMessage = 'Network error occurred';

      if (dioError.response != null) {
        if (dioError.response!.data is String &&
            dioError.response!.data.contains('<!DOCTYPE html>')) {
          errorMessage = 'Server error: Please check the API endpoint';
        } else if (dioError.response!.data is Map) {
          errorMessage =
              dioError.response!.data['message'] ?? 'Server error occurred';
        }
      } else if (dioError.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout';
      } else if (dioError.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server response timeout';
      } else if (dioError.type == DioExceptionType.connectionError) {
        errorMessage = 'Connection error - check your internet';
      }

      if (!_isDisposed && mounted) {
        _showSnackBar('Error: $errorMessage', Colors.red);
      }
    } catch (error) {
      if (!_isDisposed && mounted) {
        _showSnackBar('Error: ${error.toString()}', Colors.red);
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
    _statusStreamController.close();
    _audioPlayer.dispose();
    _hideOverlayNotification();

    MechanicSocketService.socket?.off('mechanic_location_update');
    MechanicSocketService.socket?.off('mechanic_status_update');
    MechanicSocketService.socket?.off('mechanic_request_update');

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
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading mechanic information...',
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

    final userLocation = _requestData?['userLocation'];
    final coordinates = userLocation != null
        ? userLocation['coordinates']
        : null;
    final userLat = coordinates != null && coordinates.length >= 2
        ? coordinates[1].toDouble()
        : null;
    final userLng = coordinates != null && coordinates.length >= 2
        ? coordinates[0].toDouble()
        : null;

    List<LatLng> routePoints = [];
    if (userLat != null && userLng != null && _liveDriverLocation != null) {
      final userLocationPoint = LatLng(userLat, userLng);
      routePoints.addAll([_liveDriverLocation!, userLocationPoint]);
      _routeBounds = LatLngBounds.fromPoints([
        userLocationPoint,
        _liveDriverLocation!,
      ]);
    }

    return WillPopScope(
      onWillPop: () async {
        if (_tripStatus == 'completed') {
          _handleMechanicCompleted();
          return false;
        }

        if (_tripStatus == 'cancelled') {
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
              Container(
                height: screenHeight * 0.25,
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    FlutterMap(
                      key: ValueKey(_driverLocation?.toString()),
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            _driverLocation ?? const LatLng(33.6495, 72.9767),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
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
                            if (userLat != null && userLng != null)
                              Marker(
                                point: LatLng(userLat, userLng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            if (_liveDriverLocation != null)
                              Marker(
                                point: _liveDriverLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Colors.green,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ],
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
                                if (_tripStatus == 'completed') {
                                  _handleMechanicCompleted();
                                } else if (_tripStatus == 'cancelled') {
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
                                setState(() {
                                  _driverProfile =
                                      _createDriverProfileFromMechanicData(
                                        widget.mechanicData,
                                      );
                                });
                                _fetchAddressFromCoordinates();
                                SnackBarUtil.showSuccess(
                                  context,
                                  'Refreshing mechanic information...',
                                );
                              },
                              iconColor: Colors.black,
                              iconSize: 24,
                              tooltip: 'Refresh mechanic info',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
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
                            Icons.my_location,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            if (_routeBounds != null) {
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: _routeBounds!,
                                  padding: EdgeInsets.all(screenWidth * 0.05),
                                ),
                              );
                            } else if (_liveDriverLocation != null) {
                              _mapController.move(_liveDriverLocation!, 15);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildDriverDetailsPanel()),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final id = widget.serviceRequest['_id']?.toString() ?? '';
            if (id.isEmpty) {
              SnackBarUtil.showWarning(context, 'Request ID not available');
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripChatScreen(
                  tripId: id,
                  tripModel: 'MechanicServiceRequest',
                ),
              ),
            );
          },
          child: const Icon(Icons.chat_bubble_outline),
        ),
      ),
    );
  }

  Widget _buildDriverDetailsPanel() {
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
              'Mechanic Details',
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
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                _driverProfile?['personal_info']?['avatar'] !=
                                    null
                                ? NetworkImage(
                                    _driverProfile!['personal_info']['avatar'],
                                  )
                                : null,
                            child:
                                _driverProfile?['personal_info']?['avatar'] ==
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
                                  _driverProfile?['personal_info']?['name'] ??
                                      'Mechanic Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _driverProfile?['personal_info']?['phone'] ??
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

                      Container(height: 1, color: Colors.grey[300]),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.build,
                                  color: Colors.blue[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        _driverProfile?['service_type'] ??
                                            'Car Service',
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
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.orange[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Estimated Time',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontFamily: 'UberMove',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _driverProfile?['eta'] ?? '15-20 mins',
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  'Price',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _driverProfile?['price'] ?? 'N/A',
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

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.red[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Service Location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _isFetchingAddress
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _pickupAddress,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                          fontFamily: 'UberMove',
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

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
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _driverProfile?['notes'] ??
                                      'Please have your vehicle ready for inspection',
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

                      Row(
                        children: [
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
                                  _tripStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(_tripStatus),
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

          if (_tripStatus != 'completed' && _tripStatus != 'cancelled') ...[
            Row(
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
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.018,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'UberMove',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    child: const Text('Cancel Service'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final phone = _driverProfile?['personal_info']?['phone'];
                      if (phone != null) {}
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
                    child: const Text('Call Mechanic'),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _tripStatus == 'completed'
                    ? _handleMechanicCompleted
                    : _navigateToHomeScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tripStatus == 'completed'
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
                  _tripStatus == 'completed'
                      ? 'Return to Home'
                      : 'Service Cancelled',
                ),
              ),
            ),
          ],
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
}
