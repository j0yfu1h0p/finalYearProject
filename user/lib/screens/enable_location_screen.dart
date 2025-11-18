import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../utils/snackbar_util.dart';
import './home/home_screen.dart';

class EnableLocationScreen extends StatelessWidget {
  const EnableLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final locationProvider = Provider.of<LocationProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (locationProvider.errorMessage != null) {
        SnackBarUtil.showError(context, locationProvider.errorMessage!);
      }

      if (locationProvider.position != null) {
        SnackBarUtil.showSuccess(context, "Location permission granted successfully");

        Future.delayed(const Duration(milliseconds: 1000), () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Spacer(flex: 2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/location.png',
                    width: screenWidth * 0.7,
                    height: screenHeight * 0.28,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    "Turn your location on",
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      fontFamily: "UberMove",
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    "You'll be able to find yourself on the map and drivers will be able to find you at the pickup point",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.grey,
                      fontFamily: "UberMove",
                    ),
                  ),
                ],
              ),
            ),
            Spacer(flex: 8),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: locationProvider.isLoading
                      ? null
                      : () => locationProvider.requestLocationPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  ),
                  child: locationProvider.isLoading
                      ? SizedBox(
                    height: screenHeight * 0.025,
                    width: screenHeight * 0.025,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    "Enable your location",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      fontFamily: "UberMove",
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}