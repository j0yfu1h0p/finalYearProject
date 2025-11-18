import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user/providers/location_provider.dart';
import 'package:user/providers/map_provider.dart';
import 'package:user/providers/registeration_provider.dart';
import 'package:user/providers/home_screen_provider.dart';
import 'package:user/providers/review_route_provider.dart';
import 'package:user/screens/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => HomeProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => MapProvider()),
        ChangeNotifierProvider(create: (context) => ReviewRouteProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false,
        // home: MechanicTrackingScreen(
        //   driverData: {
        //     "id": "driver123",
        //     "name": "John Doe",
        //     "phone": "+1234567890",
        //   },
        //   serviceRequest: {
        //     "id": "request456",
        //     "serviceType": "Engine Repair",
        //     "price": "75.00",
        //   },
        //   routeData: {
        //     "pickupLat": "33.6496",
        //     "pickupLng": "72.9767",
        //     "dropoffLat": "33.6502",
        //     "dropoffLng": "72.9781",
        //     "pickupLocation": "123 Main Street, Islamabad",
        //     "dropoffLocation": "Workshop Area, Islamabad",
        //   },
        // ),
      home: SplashScreen(),
    );
  }
}

