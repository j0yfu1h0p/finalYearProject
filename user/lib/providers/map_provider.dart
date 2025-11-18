import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';

import '../screens/services/vehicle_selection_screen.dart';

class MapProvider with ChangeNotifier {
  final _geo = NominatimService();
  final _router = RouteService();

  String? _selectedVehicle;
  String? _currentLocationAddress;
  String? _destinationLocationAddress;
  LatLng? _currentLocationCoords;
  LatLng? _destinationLocationCoords;
  double? _routeDistance;
  double? _routeDuration;
  List<LatLng> _routePoints = [];
  bool _isLoading = false;

  // New state variables for map control
  LatLng _mapCenter = const LatLng(30.3753, 69.3451);
  double _mapZoom = 18.0;
  bool _settingDestination = false;
  bool _permissionGranted = false;
  bool _showPermissionBanner = false;

  // Getters
  String? get selectedVehicle => _selectedVehicle;
  String? get currentLocationAddress => _currentLocationAddress;
  String? get destinationLocationAddress => _destinationLocationAddress;
  LatLng? get currentLocationCoords => _currentLocationCoords;
  LatLng? get destinationLocationCoords => _destinationLocationCoords;
  double? get routeDistance => _routeDistance;
  double? get routeDuration => _routeDuration;
  List<LatLng> get routePoints => _routePoints;
  bool get isLoading => _isLoading;
  LatLng get mapCenter => _mapCenter;
  double get mapZoom => _mapZoom;
  bool get settingDestination => _settingDestination;
  bool get permissionGranted => _permissionGranted;
  bool get showPermissionBanner => _showPermissionBanner;

  void setSelectedVehicle(String label) {
    _selectedVehicle = label;
    notifyListeners();
  }

  void updateMapPosition(LatLng center, double zoom) {
    _mapCenter = center;
    _mapZoom = zoom;
    notifyListeners();
  }

  void setSettingDestination(bool value) {
    _settingDestination = value;
    notifyListeners();
  }

  void setPermissionStatus(bool granted, bool showBanner) {
    _permissionGranted = granted;
    _showPermissionBanner = showBanner;
    notifyListeners();
  }

  Future<void> updateCurrentLocation(LatLng coords) async {
    _setLoading(true);
    try {
      final address = await _geo.reverse(coords);
      _currentLocationCoords = coords;
      _currentLocationAddress = address;
      _mapCenter = coords;
    } catch (e) {
      debugPrint('Error updating current location: $e');
      // Fallback to coordinates if address lookup fails
      _currentLocationAddress = '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDestination(String address) async {
    _setLoading(true);
    final coords = await _geo.forward(address);
    if (coords != null) {
      _destinationLocationCoords = coords;
      _destinationLocationAddress = address;
      await _calculateRoute();
    }
    _setLoading(false);
  }

  Future<void> updateDestinationFromCoords(LatLng coords) async {
    _setLoading(true);
    final address = await _geo.reverse(coords);
    _destinationLocationCoords = coords;
    _destinationLocationAddress = address;
    await _calculateRoute();
    _setLoading(false);
  }

  Future<void> _calculateRoute() async {
    if (_currentLocationCoords == null || _destinationLocationCoords == null) return;

    final result = await _router.route(_currentLocationCoords!, _destinationLocationCoords!);
    if (result != null) {
      final (distance, duration, points) = result;
      _routeDistance = distance;
      _routeDuration = duration;
      _routePoints = points;
      notifyListeners();
    }
  }

  void clearRoute() {
    _routeDistance = null;
    _routeDuration = null;
    _routePoints = [];
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}