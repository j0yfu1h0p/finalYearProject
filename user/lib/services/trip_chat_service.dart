import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:user/services/auth_service.dart';

class TripChatService {
  static final TripChatService _instance = TripChatService._internal();
  factory TripChatService() => _instance;
  TripChatService._internal();

  IO.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _historyController = StreamController<List<Map<String, dynamic>>>.broadcast();
  String? _tripId;
  String _tripModel = 'ServiceRequest';
  bool _isConnecting = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<List<Map<String, dynamic>>> get historyStream => _historyController.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connectAndJoin({required String tripId, String tripModel = 'ServiceRequest'}) async {
    _tripId = tripId;
    _tripModel = tripModel;

    if (_socket?.connected == true && _tripId == tripId) {
      _socket?.emit('join_trip_chat', { 'tripId': tripId });
      return;
    }

    if (_isConnecting) return;
    _isConnecting = true;

    if (_socket != null) {
      _socket?.disconnect();
      _socket?.clearListeners();
      _socket = null;
    }

    final token = await Auth.getToken();
    _socket = IO.io(
      'https://smiling-sparrow-proper.ngrok-free.app',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket?.onConnect((_) {
      _isConnecting = false;
      if (token != null) {
        _socket?.emit('authenticate', token);
      }
      if (_tripId != null) {
        _socket?.emit('join_trip_chat', { 'tripId': _tripId });
      }
    });

    _socket?.onDisconnect((_) {
      _isConnecting = false;
    });

    _socket?.onReconnect((_) {
      if (token != null) {
        _socket?.emit('authenticate', token);
      }
      if (_tripId != null) {
        _socket?.emit('join_trip_chat', { 'tripId': _tripId });
      }
    });

    _socket?.on('chat_history', (data) {
      try {
        if (data is List) {
          final list = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          _historyController.add(list);
        }
      } catch (e) {
      }
    });

    _socket?.on('new_message', (data) {
      try {
        if (data is Map) {
          _messageController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
      }
    });

    _socket?.on('trip_ended', (_) {
      _messageController.add({'system': true, 'message': 'Chat ended for this trip'});
    });

    _socket?.connect();
  }

  void sendMessage(String text) {
    if (_socket?.connected != true || _tripId == null || text.trim().isEmpty) return;
    _socket?.emit('send_message', {
      'tripId': _tripId,
      'message': text,
      'tripModel': _tripModel,
    });
  }

  Future<void> leave() async {
    if (_tripId != null && _socket?.connected == true) {
      _socket?.emit('leave_trip_chat', { 'tripId': _tripId });
    }
  }

  Future<void> disconnect() async {
    try { await leave(); } catch (_) {}
    _socket?.disconnect();
    _socket?.clearListeners();
    _socket = null;
    _tripId = null;
    _isConnecting = false;
  }

  Future<void> dispose() async {
    try { await leave(); } catch (_) {}
  }
}
