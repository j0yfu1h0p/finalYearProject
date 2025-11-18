import 'dart:async';
import 'package:driver/screens/role_selection.dart';
import 'package:driver/screens/sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoSlide();
  }

  void _startAutoSlide() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (activeIndex + 1) % imageUrls.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() {
          activeIndex = nextPage;
        });
      }
    });
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

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.08),
              Text(
                "MyAutoBridge",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: "UberMove",
                  fontSize: screenWidth * 0.08,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      width: imageWidth,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            activeIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              imageUrls[index],
                              fit: BoxFit.contain,
                              width: imageWidth,
                              height: imageHeight,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Text(
                      headings[activeIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: "UberMove",
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      subtitles[activeIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: "UberMove",
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imageUrls.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: activeIndex == index ? 12 : 8,
                          height: activeIndex == index ? 12 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                            activeIndex == index
                                ? Colors.black
                                : Colors.white,
                            border: Border.all(color: Colors.black),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>  RoleSelection(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.02,
                        ),
                        child: const Text(
                          "Continue with phone",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: "UberMove",
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text.rich(
                    TextSpan(
                      text: "Joining our app means you agree with our ",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth * 0.04,
                        fontFamily: "UberMove",
                      ),
                      children: [
                        TextSpan(
                          text: "Terms of Use",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontFamily: "UberMove",
                          ),
                          recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              // launchUrl(
                              //   Uri.parse("https://your-terms-link.com"),
                              // );
                            },
                        ),
                        const TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontFamily: "UberMove",
                          ),
                          recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              // launchUrl(
                              //   Uri.parse("https://your-privacy-link.com"),
                              // );
                            },
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.05),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
