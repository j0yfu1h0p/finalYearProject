import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;

  final StreamController<Map<String, dynamic>> _rideStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _driverLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _connectionStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? _userId;
  String? _currentTripId;
  bool _isReconnecting = false;
  Timer? _reconnectionTimer;
  Timer? _heartbeatTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 10;
  static const String baseUrl = 'https://smiling-sparrow-proper.ngrok-free.app';

  factory SocketService() => _instance;
  SocketService._internal();

  Stream<Map<String, dynamic>> get rideStatusStream => _rideStatusController.stream;
  Stream<Map<String, dynamic>> get driverLocationStream => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get connectionStatusStream => _connectionStatusController.stream;

  bool get isConnected => _socket?.connected ?? false;
  IO.Socket? get socket => _socket;

  Future<void> connect(String userId) async {
    _userId = userId;
    final token = await Auth.getToken();
    if (token == null) throw Exception('No authentication token');

    disconnect();

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setReconnectionAttempts(999)
          .build(),
    );

    _setupSocketListeners();
    _socket?.connect();
  }

  void _setupSocketListeners() {
    _socket?.onConnect((_) async {
      _reconnectionAttempts = 0;
      _isReconnecting = false;

      final token = await Auth.getToken();
      if (token != null) {
        _socket?.emit('authenticate', token);
      }

      _connectionStatusController.add({
        'status': 'connected',
        'timestamp': DateTime.now().toIso8601String(),
      });

      _checkForActiveRide();
      _startHeartbeat();
    });

    _socket?.onReconnect((_) async {
      final token = await Auth.getToken();
      if (token != null) {
        _socket?.emit('authenticate', token);
      }

      _connectionStatusController.add({
        'status': 'reconnected',
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (_currentTripId != null) {
        _socket?.emit('join_trip', {'tripId': _currentTripId});
      }

      _checkForActiveRide();
    });

    _socket?.onDisconnect((_) {
      _connectionStatusController.add({
        'status': 'disconnected',
        'timestamp': DateTime.now().toIso8601String(),
      });
      _stopHeartbeat();
      _attemptReconnection();
    });

    _socket?.onError((e) {
      _connectionStatusController.add({
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _socket?.on('authenticated', (data) {
    });

    _socket?.on('ride_status_update', _handleRideStatusUpdate);
    _socket?.on('driver_assigned', _handleDriverAssigned);
    _socket?.on('driver_arrived', _handleDriverArrived);
    _socket?.on('trip_started', _handleTripStarted);
    _socket?.on('user_cancelled_ride', _handleRideCancelled);

    _socket?.on('driver_location_update', (data) {
      if (data is Map) {
        _driverLocationController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket?.on('driver_disconnected', (data) {
      _rideStatusController.add({
        'type': 'driver_disconnected',
        ...Map<String, dynamic>.from(data is Map ? data : {}),
      });
    });

    _socket?.on('mechanic_disconnected', (data) {
      _rideStatusController.add({
        'type': 'mechanic_disconnected',
        ...Map<String, dynamic>.from(data is Map ? data : {}),
      });
    });

    _socket?.on('active_ride_found', (data) {
      if (data is Map) {
        _rideStatusController.add({
          'type': 'active_ride_found',
          ...Map<String, dynamic>.from(data),
        });
      }
    });

    _socket?.on('no_active_ride', (_) {
      _rideStatusController.add({'type': 'no_active_ride'});
    });
  }

  void _attemptReconnection() {
    if (_isReconnecting || _reconnectionAttempts >= _maxReconnectionAttempts) {
      return;
    }

    _isReconnecting = true;
    _reconnectionAttempts++;

    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(Duration(seconds: 2 * _reconnectionAttempts), () {
      if (!isConnected && _userId != null) {
        connect(_userId!);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (isConnected) {
        _socket?.emit('heartbeat', {'userId': _userId, 'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  Future<void> _checkForActiveRide() async {
    _socket?.emit('check_active_ride');

    try {
      final token = await Auth.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/services/active-ride'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hasActiveRide'] == true && data['data'] != null) {
          _rideStatusController.add({
            'type': 'active_ride_found',
            'tripId': data['data']['_id'],
            'status': data['data']['status'],
            'driverId': data['data']['driverId']?['_id'],
            'driverData': data['data']['driverId'],
            'serviceRequest': data['data'],
          });
        }
      }
    } catch (e) {
    }
  }

  Future<Map<String, dynamic>?> checkActiveRide() async {
    try {
      final token = await Auth.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/services/active-ride'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hasActiveRide'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkActiveMechanicRequest() async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/mechanic/requests/user/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _handleRideStatusUpdate(dynamic data) {
    try {
      if (data is Map) {
        _rideStatusController.add({
          'type': 'status_update',
          ...Map<String, dynamic>.from(data),
        });
      }
    } catch (e) {
    }
  }

  void _handleDriverAssigned(dynamic data) {
    try {
      if (data is Map) {
        _rideStatusController.add({
          'type': 'driver_assigned',
          ...Map<String, dynamic>.from(data),
        });
      }
    } catch (e) {
    }
  }

  void _handleDriverArrived(dynamic data) {
    try {
      if (data is Map) {
        _rideStatusController.add({
          'type': 'driver_arrived',
          ...Map<String, dynamic>.from(data),
        });
      }
    } catch (e) {
    }
  }

  void _handleTripStarted(dynamic data) {
    try {
      if (data is Map) {
        _rideStatusController.add({
          'type': 'trip_started',
          ...Map<String, dynamic>.from(data),
        });
      }
    } catch (e) {
    }
  }

  void _handleRideCancelled(dynamic data) {
    try {
      if (data is Map) {
        _rideStatusController.add({
          'type': 'ride_cancelled',
          ...Map<String, dynamic>.from(data),
        });
      }
    } catch (e) {
    }
  }

  void joinDriverTracking(String driverId, String tripId) {
    _currentTripId = tripId;
    _socket?.emit('join_driver_tracking', {'driverId': driverId, 'tripId': tripId});
  }

  void registerActiveTrip(String tripId, String driverId, String userId) {
    _currentTripId = tripId;
    _socket?.emit('register_active_trip', {
      'tripId': tripId,
      'driverId': driverId,
      'userId': userId,
    });
  }

  void clearActiveTrip(String tripId, String? driverId) {
    _socket?.emit('clear_active_trip', {
      'tripId': tripId,
      'driverId': driverId,
      'userId': _userId,
    });
    _currentTripId = null;
  }

  void cancelRide(String requestId, String? driverId) {
    _socket?.emit('user_cancelled_ride', {
      'requestId': requestId,
      'driverId': driverId,
    });
  }

  void disconnect() {
    _reconnectionTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.disconnect();
    _socket = null;
    _isReconnecting = false;
    _reconnectionAttempts = 0;
  }

  void dispose() {
    disconnect();
    _rideStatusController.close();
    _driverLocationController.close();
    _connectionStatusController.close();
  }
}
