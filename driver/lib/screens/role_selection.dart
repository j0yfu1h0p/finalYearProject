import 'package:driver/screens/sign_in.dart';
import 'package:flutter/material.dart';

import 'mechanic_registration/mechanic_registration.dart';

/// Clean and responsive Mechanic/Driver choice page
///
/// Features:
/// - Centered layout
/// - Scrollable for small screens
/// - MaterialPageRoute navigation
/// - UberMove font applied consistently
class RoleSelection extends StatelessWidget {
  const RoleSelection({Key? key}) : super(key: key);

  /// Navigation using MaterialPageRoute
  void _navigateToRole(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final String role; // "driver" or "mechanic"
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Name Section
                Column(
                  children: const [
                    Text(
                      'MyAutoBridge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        height: 1.1,
                        fontFamily: "UberMove",
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Professional Auto Services',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                        fontFamily: "UberMove",
                      ),
                    ),
                  ],
                ),

                SizedBox(height: screenHeight * 0.15),

                // Section Title
                const Text(
                  'Choose Your Role',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    fontFamily: "UberMove",
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select how you want to join our platform',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    letterSpacing: 0.3,
                    fontFamily: "UberMove",
                  ),
                ),

                SizedBox(height: screenHeight * 0.12),
                _buildButton(
                  context: context,
                  text: 'Login',
                  subtitle: 'Access features',
                  icon: Icons.swap_horiz_rounded,
                  isPrimary: true,
                  onPressed: () => _navigateToRole(context, const SignIn(role: "login")),                ),
                SizedBox(height: screenHeight * 0.03),

                // Mechanic Button
                _buildButton(
                  context: context,
                  text: 'Mechanic Registration',
                  subtitle: 'Offer repair services',
                  icon: Icons.build_rounded,
                  isPrimary: false,
                  onPressed: () => _navigateToRole(context, const SignIn(role: "mechanic")),                ),

                SizedBox(height: screenHeight * 0.03),

// Driver Button
                _buildButton(
                  context: context,
                  text: 'Driver Registration',
                  subtitle: 'Find tow services',
                  icon: Icons.directions_car_rounded,
                  isPrimary: false,
                  onPressed: () => _navigateToRole(context, const SignIn(role: "driver")),                ),




                SizedBox(height: screenHeight * 0.06),


                // Footer
                const Text(
                  'Connecting drivers with trusted mechanics',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontFamily: "UberMove",
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Custom button builder
  Widget _buildButton({
    required BuildContext context,
    required String text,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.transparent,
          foregroundColor: isPrimary ? Colors.black : Colors.white,
          elevation: 0,
          side: BorderSide(color: Colors.white, width: isPrimary ? 0 : 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 28, color: isPrimary ? Colors.black : Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? Colors.black : Colors.white,
                      letterSpacing: 0.3,
                      fontFamily: "UberMove",
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isPrimary ? Colors.black54 : Colors.white60,
                      letterSpacing: 0.2,
                      fontFamily: "UberMove",
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: isPrimary ? Colors.black54 : Colors.white60),
          ],
        ),
      ),
    );
  }
}

/// Placeholder pages for navigation
class MechanicRegistrationPage extends StatelessWidget {
  const MechanicRegistrationPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mechanic Registration")),
      body: const Center(child: Text("Mechanic Registration Page")),
    );
  }
}

class DriverRegistrationPage extends StatelessWidget {
  const DriverRegistrationPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Registration")),
      body: const Center(child: Text("Driver Registration Page")),
    );
  }
}
