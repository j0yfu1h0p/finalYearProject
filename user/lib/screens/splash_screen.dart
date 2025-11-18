import 'package:flutter/material.dart';
import 'package:user/screens/continue_with_phone.dart';
import 'package:user/screens/home/home_screen.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import 'services/driver_tracking_screen.dart';
import 'services/car_services/mechanic_tracking_scree.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  static const splashDelay = Duration(seconds: 1);
  static const splashText = "MyAutoBridge";
  static const backgroundColor = Colors.black;
  static const textColor = Colors.white;
  static const fontWeight = FontWeight.bold;
  static const fontFamily = "UberMove";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    await Future.delayed(splashDelay);

    if (!mounted) return;

    try {
      final token = await Auth.getToken();

      if (token != null) {
        await _checkAndNavigate();
      } else {
        _navigateToAuthScreen();
      }
    } catch (error) {
      _navigateToAuthScreen();
    }
  }

  Future<void> _checkAndNavigate() async {
    try {
      final socketService = SocketService();
      final userId = await Auth.getUserId();

      if (userId != null) {
        await socketService.connect(userId);

        final activeRide = await socketService.checkActiveRide();

        if (activeRide != null && mounted) {
          final status = activeRide['status'];

          if (status == 'accepted' || status == 'arrived' || status == 'in_progress') {
            final vehicles = activeRide['driverId']?['vehicles'];
            final vehicleData = (vehicles != null && vehicles is List && vehicles.isNotEmpty)
                ? vehicles[0]
                : null;

            final pickupCoords = activeRide['pickupLocation']?['location']?['coordinates'];
            final pickupLat = (pickupCoords != null && pickupCoords is List && pickupCoords.length > 1)
                ? pickupCoords[1]?.toString() ?? ''
                : '';
            final pickupLng = (pickupCoords != null && pickupCoords is List && pickupCoords.isNotEmpty)
                ? pickupCoords[0]?.toString() ?? ''
                : '';

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DriverTrackingScreen(
                  driverData: {
                    "_id": activeRide['driverId']?['_id'] ?? '',
                    "id": activeRide['driverId']?['_id'] ?? '',
                    "name": "${activeRide['driverId']?['personal_info']?['first_name'] ?? ''} ${activeRide['driverId']?['personal_info']?['last_name'] ?? ''}".trim(),
                    "phone": activeRide['driverId']?['phoneNumber'] ?? '',
                    "avatar": activeRide['driverId']?['personal_info']?['profile_photo_url'],
                    "vehicle": vehicleData,
                    "rating": activeRide['driverId']?['rating']?.toString() ?? '0',
                  },
                  serviceRequest: activeRide,
                  routeData: {
                    "pickupLat": pickupLat,
                    "pickupLng": pickupLng,
                    "dropoffLat": activeRide['destination']?['coordinates']?['lat']?.toString() ?? '',
                    "dropoffLng": activeRide['destination']?['coordinates']?['lng']?.toString() ?? '',
                    "pickupLocation": activeRide['pickupLocation']?['address'] ?? '',
                    "dropoffLocation": activeRide['destination']?['address'] ?? '',
                    "destinationLocation": activeRide['destination']?['address'] ?? '',
                  },
                ),
              ),
            );
            return;
          }
        }

        final activeMechanicRequest = await socketService.checkActiveMechanicRequest();

        if (activeMechanicRequest != null && mounted) {
          final status = activeMechanicRequest['status'];

          if (status == 'accepted' || status == 'arrived' || status == 'in-progress') {
            final mechanicData = activeMechanicRequest['mechanicId'];

            final userLocationCoords = activeMechanicRequest['userLocation']?['coordinates'];
            final userLat = (userLocationCoords != null && userLocationCoords is List && userLocationCoords.length > 1)
                ? userLocationCoords[1]?.toString() ?? '0'
                : '0';
            final userLng = (userLocationCoords != null && userLocationCoords is List && userLocationCoords.isNotEmpty)
                ? userLocationCoords[0]?.toString() ?? '0'
                : '0';

            final mechanicDataForScreen = {
              "id": mechanicData?['_id'] ?? '',
              "name": mechanicData?['personName'] ?? mechanicData?['shopName'] ?? 'Mechanic',
              "shopName": mechanicData?['shopName'] ?? '',
              "phone": mechanicData?['phoneNumber'] ?? '',
              "rating": mechanicData?['rating']?.toString() ?? '0',
              "location": mechanicData?['location'],
              "servicesOffered": mechanicData?['servicesOffered'],
              "address": mechanicData?['address'],
              "personalPhotoUrl": mechanicData?['personalPhotoUrl'],
            };

            final serviceRequestForScreen = {
              "id": activeMechanicRequest['_id'],
              "serviceType": activeMechanicRequest['serviceType'],
              "price": activeMechanicRequest['priceQuote']?['amount']?.toString() ?? 'N/A',
              "status": activeMechanicRequest['status'],
              "notes": activeMechanicRequest['notes'] ?? '',
              "priceQuote": activeMechanicRequest['priceQuote'],
              "userLocation": activeMechanicRequest['userLocation'],
              "createdAt": activeMechanicRequest['createdAt'],
              ...activeMechanicRequest,
            };

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MechanicTrackingScreen(
                  mechanicData: mechanicDataForScreen,
                  serviceRequest: serviceRequestForScreen,
                  routeData: {
                    "pickupLat": userLat,
                    "pickupLng": userLng,
                    "dropoffLat": userLat,
                    "dropoffLng": userLng,
                    "pickupLocation": "Your Location",
                    "dropoffLocation": "Service Location",
                  },
                ),
              ),
            );
            return;
          }
        }
      }

      _navigateToHomeScreen();
    } catch (e) {
      _navigateToHomeScreen();
    }
  }

  void _navigateToHomeScreen() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _navigateToAuthScreen() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ContinueWithPhone()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final fontSize = screenWidth * 0.08;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Text(
            splashText,
            style: TextStyle(
              color: textColor,
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}