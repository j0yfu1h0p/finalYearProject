import 'package:driver/providers/driver_requests_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/driver_registration_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RegistrationProvider()),
        ChangeNotifierProvider(create: (ctx) => DriverRequestsProvider()),

      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Driver App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
        ),
        home: const SplashScreen(),
        // home: MechanicRegistrationScreen(),
      ),
    ),
  );
}
