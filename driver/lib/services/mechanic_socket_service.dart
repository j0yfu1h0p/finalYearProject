// services/mechanic_socket_service.dart
import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:driver/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';

class MechanicSocketService {
  static IO.Socket? _socket;
  static String? _currentMechanicId;
  static final StreamController<Map<String, dynamic>> _newMechanicRequestController =
  StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get newMechanicRequestStream => _newMechanicRequestController.stream;
  static IO.Socket? get socket => _socket;

  static Future<void> initializeSocket(String mechanicId) async {
    try {
      final token = await Auth.getToken();
      if (token == null) return;

      _currentMechanicId = mechanicId;

      if (_socket == null) {
        _socket = IO.io(
          'https://smiling-sparrow-proper.ngrok-free.app',
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .build(),
        );

        _socket!.onConnect((_) async {
          _socket!.emit('authenticate', token);
          if (_currentMechanicId != null) {
            joinMechanicTracking(_currentMechanicId!, '');
          }
        });

        _socket!.on('authenticated', (data) {
          try {
            final ok = (data is Map && data['success'] == true) || (data is String && data.contains('true'));
          } catch (_) {}
        });

        _socket!.on('new_mechanic_request', (data) {
          try {
            if (data is Map<String, dynamic>) {
              _newMechanicRequestController.add(Map<String, dynamic>.from(data));
            }
          } catch (e) {}
        });

        // Server requests location update periodically for connected mechanics
        _socket!.on('request_location_update', (data) async {
          if (_currentMechanicId == null) return;
          try {
            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            sendLocationUpdate(_currentMechanicId!, {
              'lat': pos.latitude,
              'lng': pos.longitude,
              'accuracy': pos.accuracy,
              'heading': pos.heading,
              'speed': pos.speed,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          } catch (e) {}
        });

        _socket!.onDisconnect((_) {});
        _socket!.onError((error) {});

        if (!_socket!.connected) {
          _socket!.connect();
        }
      }
    } catch (e) {}
  }

  static void dispose() {
    _socket?.disconnect();
    _socket = null;
    _currentMechanicId = null;
  }

  static void joinRequestRoom(String requestId) {
    _socket?.emit('join_request', {'serviceRequestId': requestId});
  }

  static void leaveRequestRoom(String requestId) {
    _socket?.emit('leave_request', {'serviceRequestId': requestId});
  }

  static void joinMechanicTracking(String mechanicId, String requestId) {
    _currentMechanicId = mechanicId;
    _socket?.emit('join_mechanic_tracking', {
      'mechanicId': mechanicId,
      'requestId': requestId
    });
  }

  static void sendLocationUpdate(String mechanicId, Map<String, dynamic> location) {
    _socket?.emit('mechanic_location_update', {
      'mechanicId': mechanicId,
      'location': location
    });
  }

  static void emitMechanicArrived(String requestId) {
    _socket?.emit('mechanic_arrived', {'requestId': requestId});
  }

  static void emitMechanicJobStarted(String requestId) {
    _socket?.emit('mechanic_job_started', {'requestId': requestId});
  }

  static void emitMechanicJobCompleted(String requestId, String mechanicId) {
    _socket?.emit('mechanic_job_completed', {
      'requestId': requestId,
      'mechanicId': mechanicId
    });
  }

  static void emitMechanicCancelledJob(String requestId, String userId) {
    _socket?.emit('mechanic_cancelled_job', {
      'requestId': requestId,
      'userId': userId
    });
  }
}