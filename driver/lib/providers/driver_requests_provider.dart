import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_request_screen_model.dart';
import '../models/mechanic_service_request_model.dart';
import '../services/api_services.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../services/mechanic_socket_service.dart';

class DriverRequestsProvider with ChangeNotifier {
  List<ServiceRequest> _driverRequests = [];
  List<MechanicServiceRequest> _mechanicRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  String? _driverId;
  final SocketService _socketService = SocketService();

  // Stream subscriptions for real-time updates
  StreamSubscription? _newRideRequestSubscription;
  StreamSubscription? _newMechanicRequestSubscription;

  // Role approval statuses
  String _driverStatus = 'pending';
  String _mechanicStatus = 'pending';

  List<ServiceRequest> get driverRequests => _driverRequests;
  List<MechanicServiceRequest> get mechanicRequests => _mechanicRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRefreshing => _isRefreshing;
  bool get isLoggingOut => _isLoggingOut;
  String? get driverId => _driverId;
  SocketService get socketService => _socketService;

  String get driverStatus => _driverStatus;
  String get mechanicStatus => _mechanicStatus;

  // Load role statuses from local storage
  Future<void> _loadStatusesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _driverStatus = prefs.getString('driverStatus') ?? 'pending';
    _mechanicStatus = prefs.getString('mechanicStatus') ?? 'pending';
  }

  // Load pending requests based on role approvals
  Future<void> loadPendingRequests() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _loadStatusesFromPrefs();

      final futures = <Future<dynamic>>[];

      // Fetch driver requests only if driver role is approved
      if (_driverStatus == 'approved') {
        futures.add(ApiService.getPendingRequests());
      } else {
        futures.add(Future.value(<ServiceRequest>[]));
      }

      // Fetch mechanic requests only if mechanic role is approved
      if (_mechanicStatus == 'approved') {
        futures.add(ApiService.getPendingMechanicRequests());
      } else {
        futures.add(Future.value(<MechanicServiceRequest>[]));
      }

      final results = await Future.wait(futures);

      _driverRequests = results[0] as List<ServiceRequest>;
      _mechanicRequests = results[1] as List<MechanicServiceRequest>;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadNearbyDriverRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Only fetch if driver status is approved
      if (_driverStatus != 'approved') {
        _driverRequests = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      _driverRequests = await ApiService.getNearbyPendingRequests(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadMechanicRequests() async {
    if (_mechanicStatus != 'approved') return;
    try {
      _mechanicRequests = await ApiService.getPendingMechanicRequests();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> initializeSocketConnection() async {
    try {
      final token = await Auth.getToken();
      if (token == null) {
        return;
      }

      await _loadStatusesFromPrefs();

      bool isDriverConnected = false;
      bool isMechanicConnected = false;

      // Connect driver socket if approved
      if (_driverStatus == 'approved') {
        final driverId = await _getDriverIdFromToken();
        if (driverId != null) {
          _driverId = driverId;
          await _socketService.connect(driverId);
          isDriverConnected = true;
        }
      }

      // Connect mechanic socket if approved
      if (_mechanicStatus == 'approved') {
        final mechanicId = await _getMechanicIdFromToken();
        if (mechanicId != null) {
          await MechanicSocketService.initializeSocket(mechanicId);
          isMechanicConnected = true;
        }
      }

      if (isDriverConnected || isMechanicConnected) {
        _setupNotificationListeners();
        notifyListeners();
      }
    } catch (e) {}
  }

  void _setupNotificationListeners() {
    // Listen for new ride requests (for drivers)
    _newRideRequestSubscription = _socketService.newRideRequestStream.listen((newRequest) {
      // Refresh driver requests to show the new request
      if (_driverStatus == 'approved') {
        loadPendingRequests();
      }
    });

    // Listen for new mechanic requests (for mechanics)
    _newMechanicRequestSubscription = MechanicSocketService.newMechanicRequestStream.listen((newRequest) {
      // Refresh mechanic requests to show the new request
      if (_mechanicStatus == 'approved') {
        loadPendingRequests();
      }
    });

    // Listen for socket status updates
    _socketService.statusStream.listen((statusData) {
      // Handle status updates if needed
    });
  }

  Future<void> acceptDriverRequest(String requestId) async {
    try {
      await ApiService.acceptRequest(requestId);
      _driverRequests.removeWhere((request) => request.id == requestId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<MechanicServiceRequest?> acceptMechanicRequest(String requestId) async {
    try {
      // Call API to accept and get updated request document
      final doc = await ApiService.acceptMechanicRequest(requestId);

      final index = _mechanicRequests.indexWhere((request) => request.id == requestId);

      if (index != -1) {
        final acceptedRequest = _mechanicRequests[index];
        _mechanicRequests.removeAt(index);
        notifyListeners();
        return acceptedRequest;
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _getDriverIdFromToken() async {
    try {
      final profile = await ApiService.getDriverProfile();
      return profile?['_id'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getMechanicIdFromToken() async {
    try {
      final profile = await ApiService.getMechanicProfile();
      return profile?['_id'];
    } catch (e) {
      return null;
    }
  }

  void setRefreshing(bool value) {
    _isRefreshing = value;
    notifyListeners();
  }

  void setLoggingOut(bool value) {
    _isLoggingOut = value;
    notifyListeners();
  }

  void disconnectSocket() {
    _socketService.disconnect();
    MechanicSocketService.dispose();
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    _newRideRequestSubscription?.cancel();
    _newMechanicRequestSubscription?.cancel();

    // Disconnect sockets
    disconnectSocket();

    super.dispose();
  }
}