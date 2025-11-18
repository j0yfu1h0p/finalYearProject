import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/snackbar_util.dart';
import 'continue_with_phone.dart';
import 'ride_requese_dashboard/driver_requests_dashboard.dart';
import 'splash_screen.dart';

class RegistrationStatusScreen extends StatefulWidget {
  /// Map of roles to registration status, e.g. {'driver': 'pending', 'mechanic': 'approved'}
  final Map<String, String> statuses;

  const RegistrationStatusScreen({super.key, required this.statuses});

  @override
  State<RegistrationStatusScreen> createState() => _RegistrationStatusScreenState();
}

class _RegistrationStatusScreenState extends State<RegistrationStatusScreen> {
  bool _isLoggingOut = false;

  /// Logout handler: clears token and navigates to phone login
  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await Auth.removeToken();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ContinueWithPhone()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtil.showError(context, 'Logout failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  /// Re-check registration status
  void _checkStatusAgain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  /// Maps status to icon, color, and default messages
  /// Returns null if the status is not recognized
  Map<String, dynamic>? _getStatusDisplay(String status) {
    switch (status) {
      case 'pending':
        return {
          'icon': Icons.hourglass_top_rounded,
          'color': Colors.orange,
          'title': 'Pending Review',
          'message': 'Your registration is under review',
          'details': 'We will notify you once approved. This process typically takes 24-48 hours.'
        };
      case 'approved':
        return {
          'icon': Icons.check_circle_rounded,
          'color': Colors.green,
          'title': 'Approved',
          'message': 'Your registration was approved',
          'details': 'You can now start accepting requests.'
        };
      case 'rejected':
        return {
          'icon': Icons.error_outline_rounded,
          'color': Colors.red,
          'title': 'Registration Rejected',
          'message': 'Your registration was not approved',
          'details': 'Please contact support for more information.'
        };
      default:
        return null; // unknown statuses will be ignored
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter only valid statuses
    final statusEntries = widget.statuses.entries
        .where((entry) => entry.value != null && entry.value != 'not_registered')
        .toList();

    // Determine if any role is approved
    bool anyApproved = statusEntries.any((entry) => entry.value == 'approved');

    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Registration Status', style: TextStyle(color: Colors.black, fontFamily: "UberMove", fontWeight: FontWeight.w600, fontSize: 20)),
            backgroundColor: Colors.white,
            elevation: 1,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: TextButton(
                  onPressed: _logout,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Log out', style: TextStyle(fontFamily: "UberMove", fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Instruction
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'If your requested role/status is not showing here, please log out and log in again to refresh your account.',
                        style: TextStyle(fontSize: 14, color: Colors.black87, fontFamily: "UberMove"),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Text(
                      'Your registration status',
                      style: TextStyle(fontSize: 16, color: Colors.black54, fontFamily: "UberMove"),
                    ),
                    const SizedBox(height: 16),

                    // Expanded list of status cards
                    Expanded(
                      child: ListView.separated(
                        itemCount: statusEntries.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final entry = statusEntries[index];
                          final display = _getStatusDisplay(entry.value);
                          if (display == null) return const SizedBox.shrink();

                          final role = entry.key;
                          final status = entry.value;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(role.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54, fontFamily: "UberMove")),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: display['color'].withOpacity(0.1), shape: BoxShape.circle),
                                        child: Icon(display['icon'], size: 28, color: display['color']),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(display['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: display['color'], fontFamily: "UberMove")),
                                            const SizedBox(height: 4),
                                            Text(display['message'], style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: "UberMove")),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(display['details'], style: const TextStyle(fontSize: 14, color: Colors.black54, fontFamily: "UberMove", height: 1.4)),
                                  const SizedBox(height: 16),

                                  if (status == 'rejected') ...[
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    const Text('Need help? Contact our support team:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "UberMove")),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, color: Colors.green[700], size: 20),
                                        const SizedBox(width: 8),
                                        Text('+92-316-9977808', style: TextStyle(fontSize: 14, color: Colors.green[700], fontFamily: "UberMove")),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.email, color: Colors.green[700], size: 20),
                                        const SizedBox(width: 8),
                                        Text('support@myautobridge.com', style: TextStyle(fontSize: 14, color: Colors.green[700], fontFamily: "UberMove")),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Button(s) at the bottom
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: anyApproved
                            ? () {
                          // Go to Ride Requests Dashboard and pass roles + statuses
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideRequestsDashboard(
                              ),
                            ),
                          );
                        }
                            : _checkStatusAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: anyApproved ? Colors.green : Colors.white,
                          foregroundColor: anyApproved ? Colors.white : Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: anyApproved ? BorderSide.none : BorderSide(color: Colors.green),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          anyApproved ? 'Go to Dashboard' : 'Check Status Again',
                          style: const TextStyle(fontSize: 16, fontFamily: "UberMove", fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isLoggingOut)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),);
    }
}
