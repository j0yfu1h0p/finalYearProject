// review_route_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';

class ReviewRouteProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _showTimeoutWarning = false;
  Timer? _loadingTimer;

  bool get isLoading => _isLoading;
  bool get showTimeoutWarning => _showTimeoutWarning;

  void startLoading() {
    _isLoading = true;
    _showTimeoutWarning = false;
    _startLoadingTimer();
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    _stopLoadingTimer();
    notifyListeners();
  }

  void _startLoadingTimer() {
    _loadingTimer = Timer(const Duration(seconds: 10), () {
      _showTimeoutWarning = true;
      notifyListeners();
    });
  }

  void _stopLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _showTimeoutWarning = false;
  }

  @override
  void dispose() {
    _stopLoadingTimer();
    super.dispose();
  }
}