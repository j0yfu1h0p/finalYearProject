import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:driver/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;

  // Stream controllers for real-time updates
  final StreamController<Map<String, dynamic>> _statusController =
  StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _locationRequestController =
  StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _newRideRequestController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newRideRequestStream => _newRideRequestController.stream;

  // Live driver location stream for UI updates
  final StreamController<Map<String, dynamic>> _locationController =
  StreamController<Map<String, dynamic>>.broadcast();

  String? _driverId;
  String? _currentTripId;
  Timer? _locationTimer;
  bool _isSendingLocation = false;
  bool _isOnTrip = false;

  factory SocketService() => _instance;
  SocketService._internal();

  static SocketService getInstance() => _instance;

  // Exposed streams for external access
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get locationRequestStream =>
      _locationRequestController.stream;

  // Use this in the UI to animate the driver marker
  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  String? get driverId => _driverId;
  bool get isConnected => _socket?.connected ?? false;
  bool get isOnTrip => _isOnTrip;
  IO.Socket? get socket => _socket;

  // Establish WebSocket connection
  Future<void> connect(String driverId) async {
    _driverId = driverId;
    final token = await Auth.getToken();
    if (token == null) throw Exception('No authentication token');

    disconnect();

    _socket = IO.io(
      'https://smiling-sparrow-proper.ngrok-free.app',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _setupSocketListeners();

    _socket?.connect();
  }

  // Configure socket event listeners
  void _setupSocketListeners() {
    _socket?.onConnect((_) async {
      final token = await Auth.getToken();
      if (token != null) {
        _socket?.emit('authenticate', token);
      }
      // Rejoin active trip if exists after reconnect
      if (_currentTripId != null && _driverId != null) {
        _socket?.emit('rejoin_trip_tracking', {
          'driverId': _driverId,
          'tripId': _currentTripId,
        });
      }
    });

    _socket?.onReconnect((_) async {
      final token = await Auth.getToken();
      if (token != null) {
        _socket?.emit('authenticate', token);
      }
      // Rejoin active trip if exists after reconnect
      if (_currentTripId != null && _driverId != null) {
        _socket?.emit('rejoin_trip_tracking', {
          'driverId': _driverId,
          'tripId': _currentTripId,
        });
      }
    });

    _socket?.onDisconnect((_) {});
    _socket?.onError((e) {});

    _socket?.on('authenticated', (d) {});

    // Handle rejoin trip tracking response
    _socket?.on('rejoin_trip_tracking', (data) {
      if (data is Map) {
        final response = Map<String, dynamic>.from(data);
        if (response['success'] == true) {
          _isOnTrip = true;
          _currentTripId = response['tripId'];

          _statusController.add({
            'type': 'trip_rejoined',
            'tripId': response['tripId'],
            'status': response['status'],
            'tripData': response['tripData'],
          });
        } else {
          _isOnTrip = false;
          _currentTripId = null;
        }
      }
    });

    // Server periodically requests location updates
    _socket?.on('request_location_update', (d) {
      _locationRequestController.add(Map<String, dynamic>.from(d));
      if (_isOnTrip) {
        _sendCurrentLocation();
      }
    });

    // Listen for various status updates
    _socket?.on('ride_status_update', _handleStatusUpdate);
    _socket?.on('ride_cancelled_by_user', _handleStatusUpdate);
    _socket?.on('statusUpdate', _handleStatusUpdate);
    _socket?.on('statusSync', _handleStatusUpdate);
    _socket?.on('driver_status_changed', _handleStatusUpdate);
    _socket?.on('new_ride_request', (data) {
      try {
        if (data is Map<String, dynamic>) {
          _newRideRequestController.add(data);
        }
      } catch (e) {}
    });

    // Handle driver location updates
    _socket?.on('driver_location_update', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final loc = map['location'] is Map ? Map<String, dynamic>.from(map['location']) : map;
        _locationController.add(loc);
      }
    });

    // Handle explicit user cancellation
    _socket?.on('user_cancelled_ride', (data) {
      _statusController.add({
        'type': 'user_cancelled_ride',
        ...Map<String, dynamic>.from(data is Map ? data : {}),
      });
    });
  }

  // Process incoming status updates
  void _handleStatusUpdate(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        _statusController.add(data);
      } else if (data is String) {
        _statusController.add(Map<String, dynamic>.from(jsonDecode(data)));
      }
    } catch (e) {}
  }

  void disconnect() {
    stopLocationUpdates();
    _socket?.disconnect();
    _socket = null;
    _driverId = null;
    _currentTripId = null;
    _isOnTrip = false;
  }

  // Join driver tracking for a specific trip
  void joinDriverTracking(String tripId) {
    _currentTripId = tripId;
    _isOnTrip = true;
    _socket?.emit('join_driver_tracking', {'driverId': _driverId, 'tripId': tripId});
    _socket?.emit('register_active_trip', {'tripId': tripId, 'driverId': _driverId, 'userId': null});
    startLocationUpdates();
  }

  void notifyTripCompleted(String tripId) {
    _socket?.emit('driver_completed_trip', {'driverId': _driverId, 'tripId': tripId});
    _socket?.emit('clear_active_trip', {'tripId': tripId, 'driverId': _driverId, 'userId': null});
    _isOnTrip = false;
    _currentTripId = null;
    stopLocationUpdates();
  }

  void notifyDriverArrived(String tripId) =>
      _socket?.emit('driver_arrived_pickup', {'driverId': _driverId, 'tripId': tripId});

  void notifyTripStarted(String tripId) {
    _socket?.emit('trip_started', {'driverId': _driverId, 'tripId': tripId});
    _isOnTrip = true;
    startLocationUpdates();
  }

  void notifyRideCancelled(String requestId, String userId) {
    _socket?.emit('driver_cancelled_ride', {'requestId': requestId, 'userId': userId});
    _socket?.emit('clear_active_trip', {'tripId': requestId, 'driverId': _driverId, 'userId': userId});
    _isOnTrip = false;
    _currentTripId = null;
    stopLocationUpdates();
  }

  // Check if driver has an active trip in progress
  Future<Map<String, dynamic>?> checkActiveTrip() async {
    try {
      final token = await Auth.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('https://smiling-sparrow-proper.ngrok-free.app/api/driver/active-trip'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hasActiveTrip'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Start periodic location updates
  void startLocationUpdates() {
    if (_isSendingLocation) return;
    _isSendingLocation = true;
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isOnTrip) {
        _sendCurrentLocation();
      }
    });
  }

  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _isSendingLocation = false;
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      sendLocationUpdate({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'heading': pos.heading,
        'speed': pos.speed,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {}
  }

  void sendLocationUpdate(Map<String, dynamic> location) {
    _socket?.emit('driver_location_update', {'driverId': _driverId, 'location': location});
  }
}