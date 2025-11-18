import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'auth/registration_screen.dart';

class ContinueWithPhone extends StatefulWidget {
  const ContinueWithPhone({super.key});

  @override
  State<ContinueWithPhone> createState() => _ContinueWithPhoneState();
}

class _ContinueWithPhoneState extends State<ContinueWithPhone> {
  int activeIndex = 0;
  final List<String> imageUrls = [
    'assets/images/get_started_pic_1.png',
    'assets/images/get_started_pic_2.png',
  ];
  final List<String> headings = [
    'Roadside Help, Anytime You Need!',
    'Your Roadside Solution!',
  ];
  final List<String> subtitles = [
    'Whether it\'s a tow or a tune-up, we are here to get you back on the road.',
    'From towing to servicing, we\'ve got everything you need to keep moving forward.',
  ];
  late PageController _pageController;
  late Timer _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoSlide();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSlideTimer.cancel();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && mounted) {
        int nextPage = (activeIndex + 1) % imageUrls.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        if (mounted) {
          setState(() {
            activeIndex = nextPage;
          });
        }
      }
    });
  }

  void _navigateToRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegistrationScreen(),
      ),
    );
  }

  void _openTermsOfUse() {
    // Implementation for opening Terms of Use
  }

  void _openPrivacyPolicy() {
    // Implementation for opening Privacy Policy
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double screenWidth = mediaQuery.size.width;
    final double padding = screenWidth * 0.05;
    final double buttonWidth = screenWidth * 0.8;
    final double imageHeight = screenHeight * 0.25;
    final double imageWidth = screenWidth * 0.9;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.08),
              _buildAppTitle(screenWidth),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildImageCarousel(imageHeight, imageWidth),
                    SizedBox(height: screenHeight * 0.02),
                    _buildHeadingText(screenWidth),
                    SizedBox(height: screenHeight * 0.01),
                    _buildSubtitleText(screenWidth),
                    SizedBox(height: screenHeight * 0.10),
                    _buildPageIndicators(),
                  ],
                ),
              ),
              _buildBottomSection(screenWidth, screenHeight, buttonWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle(double screenWidth) {
    return Text(
      "MyAutoBridge",
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.black,
        fontFamily: "UberMove",
        fontSize: screenWidth * 0.08,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildImageCarousel(double imageHeight, double imageWidth) {
    return SizedBox(
      height: imageHeight,
      width: imageWidth,
      child: PageView.builder(
        controller: _pageController,
        itemCount: imageUrls.length,
        onPageChanged: (index) {
          if (mounted) {
            setState(() {
              activeIndex = index;
            });
          }
        },
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              imageUrls[index],
              fit: BoxFit.contain,
              width: imageWidth,
              height: imageHeight,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: imageWidth,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.image_not_supported,
                    size: imageWidth * 0.2,
                    color: Colors.grey[400],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeadingText(double screenWidth) {
    return Text(
      headings[activeIndex],
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.black,
        fontFamily: "UberMove",
        fontSize: screenWidth * 0.05,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubtitleText(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Text(
        subtitles[activeIndex],
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey[600],
          fontFamily: "UberMove",
          fontSize: screenWidth * 0.04,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(imageUrls.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: activeIndex == index ? 12 : 8,
          height: activeIndex == index ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeIndex == index ? Colors.black : Colors.white,
            border: Border.all(color: Colors.black),
          ),
        );
      }),
    );
  }

  Widget _buildBottomSection(double screenWidth, double screenHeight, double buttonWidth) {
    return Column(
      children: [
        _buildContinueButton(screenWidth, screenHeight, buttonWidth),
        SizedBox(height: screenHeight * 0.02),
        _buildTermsText(screenWidth),
        SizedBox(height: screenHeight * 0.05),
      ],
    );
  }

  Widget _buildContinueButton(double screenWidth, double screenHeight, double buttonWidth) {
    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        onPressed: _navigateToRegistration,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.02,
          ),
          child: Text(
            "Continue with phone",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: "UberMove",
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Text.rich(
        TextSpan(
          text: "Joining our app means you agree with our ",
          style: TextStyle(
            color: Colors.black,
            fontSize: screenWidth * 0.035,
            fontFamily: "UberMove",
          ),
          children: [
            TextSpan(
              text: "Terms of Use",
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                fontFamily: "UberMove",
                fontSize: screenWidth * 0.035,
              ),
              recognizer: TapGestureRecognizer()..onTap = _openTermsOfUse,
            ),
            TextSpan(
              text: " and ",
              style: TextStyle(
                color: Colors.black,
                fontSize: screenWidth * 0.035,
                fontFamily: "UberMove",
              ),
            ),
            TextSpan(
              text: "Privacy Policy",
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                fontFamily: "UberMove",
                fontSize: screenWidth * 0.035,
              ),
              recognizer: TapGestureRecognizer()..onTap = _openPrivacyPolicy,
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}