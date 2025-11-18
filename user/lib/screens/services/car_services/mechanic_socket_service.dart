import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:user/services/auth_service.dart';

class MechanicSocketService {
  static IO.Socket? _socket;

  /// Getter for socket instance
  static IO.Socket? get socket => _socket;

  /// Initializes socket connection with authentication
  static Future<void> initializeSocket() async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        _logMessage('Authentication token not available');
        return;
      }

      if (_socket == null) {
        _socket = IO.io(
          'https://smiling-sparrow-proper.ngrok-free.app',
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .setExtraHeaders({'Authorization': 'Bearer $token'})
              .build(),
        );

        _setupSocketEventHandlers(token);

        if (!_socket!.connected) {
          _socket!.connect();
        }
      }
    } catch (e) {
      _logMessage('Socket initialization error: $e');
    }
  }

  /// Sets up socket event handlers
  static void _setupSocketEventHandlers(String token) {
    _socket!.onConnect((_) {
      _logMessage('Mechanic socket connected');
      _socket!.emit('authenticate', token);
    });

    _socket!.on('authenticated', (data) {
      if (data['success'] == true) {
        _logMessage('Mechanic socket authenticated successfully');
      } else {
        _logMessage('Mechanic socket authentication failed: ${data['message']}');
      }
    });

    _socket!.onDisconnect((_) => _logMessage('Mechanic socket disconnected'));
    _socket!.onError((error) => _logMessage('Mechanic socket error: $error'));
  }

  /// Disposes socket connection and cleans up resources
  static void dispose() {
    _socket?.disconnect();
    _socket?.clearListeners();
    _socket = null;
  }

  /// Joins a specific request room for real-time updates
  static void joinRequestRoom(String requestId) {
    if (_validateSocketConnection() && _validateInput(requestId)) {
      _socket?.emit('join_request', {'serviceRequestId': requestId});
    }
  }

  /// Leaves a specific request room
  static void leaveRequestRoom(String requestId) {
    if (_validateSocketConnection() && _validateInput(requestId)) {
      _socket?.emit('leave_request', {'serviceRequestId': requestId});
    }
  }

  /// Joins mechanic tracking room for location updates
  static void joinMechanicTracking(String mechanicId, String requestId) {
    if (_validateSocketConnection() && _validateInput(mechanicId) && _validateInput(requestId)) {
      _socket?.emit('join_mechanic_tracking', {
        'mechanicId': mechanicId,
        'requestId': requestId
      });
    }
  }

  /// Sends mechanic location update to server
  static void sendLocationUpdate(String mechanicId, Map<String, dynamic> location) {
    if (_validateSocketConnection() && _validateInput(mechanicId) && _validateLocationData(location)) {
      _socket?.emit('mechanic_location_update', {
        'mechanicId': mechanicId,
        'location': location
      });
    }
  }

  /// Notifies server that mechanic has arrived at location
  static void emitMechanicArrived(String requestId) {
    if (_validateSocketConnection() && _validateInput(requestId)) {
      _socket?.emit('mechanic_arrived', {'requestId': requestId});
    }
  }

  /// Notifies server that mechanic has started the job
  static void emitMechanicJobStarted(String requestId) {
    if (_validateSocketConnection() && _validateInput(requestId)) {
      _socket?.emit('mechanic_job_started', {'requestId': requestId});
    }
  }

  /// Notifies server that mechanic has completed the job
  static void emitMechanicJobCompleted(String requestId, String mechanicId) {
    if (_validateSocketConnection() && _validateInput(requestId) && _validateInput(mechanicId)) {
      _socket?.emit('mechanic_job_completed', {
        'requestId': requestId,
        'mechanicId': mechanicId
      });
    }
  }

  /// Notifies server that mechanic has cancelled the job
  static void emitMechanicCancelledJob(String requestId, String userId) {
    if (_validateSocketConnection() && _validateInput(requestId) && _validateInput(userId)) {
      _socket?.emit('mechanic_cancelled_job', {
        'requestId': requestId,
        'userId': userId
      });
    }
  }

  /// Notifies server about service cancellation by user
  static void notifyCancellation(String mechanicId, String requestId) {
    if (_validateSocketConnection() && _validateInput(mechanicId) && _validateInput(requestId)) {
      _socket?.emit('service_cancelled', {
        'mechanicId': mechanicId,
        'requestId': requestId,
        'cancelledBy': 'user',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Validates socket connection status
  static bool _validateSocketConnection() {
    final isConnected = _socket?.connected ?? false;
    if (!isConnected) {
      _logMessage('Socket not connected');
    }
    return isConnected;
  }

  /// Validates input parameters for null or empty values
  static bool _validateInput(String input) {
    final isValid = input.isNotEmpty;
    if (!isValid) {
      _logMessage('Invalid input parameter');
    }
    return isValid;
  }

  /// Validates location data structure
  static bool _validateLocationData(Map<String, dynamic> location) {
    final hasRequiredFields = location.containsKey('latitude') &&
        location.containsKey('longitude');
    if (!hasRequiredFields) {
      _logMessage('Invalid location data structure');
    }
    return hasRequiredFields;
  }

  /// Centralized logging method
  static void _logMessage(String message) {
    // Implement proper logging mechanism here
    // Consider using a logging package like logger in production
  }
}