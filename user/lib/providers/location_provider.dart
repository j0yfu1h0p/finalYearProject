import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Position? _position;
  Position? get position => _position;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> requestLocationPermission(BuildContext context) async {
    if (_isLoading) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = "Location services are disabled.";
        _setLoading(false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _errorMessage = "Location permission denied.";
          _setLoading(false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = "Location permission permanently denied.";
        _setLoading(false);
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          _position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e) {
          _errorMessage = "Failed to get location: $e";
        }
      } else {
        _errorMessage = "Permission not granted.";
      }
    } catch (e) {
      _errorMessage = "Unexpected error: $e";
    } finally {
      _setLoading(false);
    }
  }
}
