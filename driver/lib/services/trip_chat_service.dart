import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:driver/services/websocket_service.dart';
import 'package:driver/services/mechanic_socket_service.dart';

class TripChatService {
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _historyController = StreamController<List<Map<String, dynamic>>>.broadcast();
  String? _tripId;
  String _tripModel = 'ServiceRequest';
  bool _isListening = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<List<Map<String, dynamic>>> get historyStream => _historyController.stream;

  bool get isConnected {
    if (_tripModel == 'MechanicServiceRequest') {
      return MechanicSocketService.socket?.connected ?? false;
    } else {
      return SocketService.getInstance().socket?.connected ?? false;
    }
  }

  IO.Socket? get _socket {
    if (_tripModel == 'MechanicServiceRequest') {
      return MechanicSocketService.socket;
    } else {
      return SocketService.getInstance().socket;
    }
  }

  Future<void> connectAndJoin({required String tripId, String tripModel = 'ServiceRequest'}) async {
    _tripId = tripId;
    _tripModel = tripModel;

    // Reuse existing connection
    if (!_isListening) {
      _setupChatListeners();
    }

    // Join the trip chat room
    _socket?.emit('join_trip_chat', { 'tripId': tripId });
  }

  void _setupChatListeners() {
    if (_isListening) return;
    _isListening = true;

    _socket?.on('chat_history', (data) {
      try {
        if (data is List) {
          final list = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          _historyController.add(list);
        }
      } catch (e) {}
    });

    _socket?.on('new_message', (data) {
      try {
        if (data is Map) {
          _messageController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {}
    });

    _socket?.on('trip_ended', (_) {
      _messageController.add({'system': true, 'message': 'Chat ended for this trip'});
    });
  }

  void sendMessage(String text) {
    if (_socket?.connected != true || _tripId == null || text.trim().isEmpty) {
      return;
    }
    _socket?.emit('send_message', {
      'tripId': _tripId,
      'message': text,
      'tripModel': _tripModel,
    });
  }

  Future<void> leave() async {
    if (_tripId != null) {
      _socket?.emit('leave_trip_chat', { 'tripId': _tripId });
    }
  }

  Future<void> dispose() async {
    try {
      await leave();
    } catch (_) {}
    // Socket is shared, so don't disconnect
    _tripId = null;
  }
}
