import 'dart:async';
import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  int _activeIndex = 0;
  bool _isLoggingOut = false;
  Timer? _timer;
  final PageController pageController = PageController(initialPage: 0);

  int get activeIndex => _activeIndex;
  bool get isLoggingOut => _isLoggingOut;

  final List<String> cardTexts = [
    "We come to you, no matter\nwhere you're stranded.\nFast and reliable truck\ntowing, anytime.",
    "24/7 Roadside assistance.\nQuick response and expert\nservice delivered right\nto your location."
  ];

  HomeProvider() {
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (pageController.hasClients) {
        int nextPage = (_activeIndex + 1) % cardTexts.length;
        pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _activeIndex = nextPage;
        notifyListeners();
      }
    });
  }

  void onPageChanged(int index) {
    _activeIndex = index;
    notifyListeners();
  }

  Future<void> setLoggingOut(bool value) async {
    _isLoggingOut = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    pageController.dispose();
    super.dispose();
  }
}
