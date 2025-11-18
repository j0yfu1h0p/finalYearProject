import 'package:admin/screens/login.dart';
import 'package:admin/screens/super_admin/rates_tab.dart';
import 'package:admin/screens/super_admin/super_admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:admin/auth_service.dart';
import 'package:admin/utils/snackbar_util.dart';
import 'activity_logs_tab.dart';
import 'admins_tab.dart';

class SuperAdminStepper extends StatefulWidget {
  const SuperAdminStepper({Key? key}) : super(key: key);

  @override
  State<SuperAdminStepper> createState() => _SuperAdminStepperState();
}

class _SuperAdminStepperState extends State<SuperAdminStepper> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  late final List<Widget> _screens;

  late final List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();

    _screens = const [
      SuperAdminDashboard(),
      AdminsTab(),
      RatesTab(),
      ActivityLogsTab(),
    ];

    _navItems = const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Admins'),
      BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Rates'),
      BottomNavigationBarItem(icon: Icon(Icons.history), label: 'ActivityLogsTab'),
      BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Logout'),
    ];

    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    setState(() => _isLoading = true);
    try {
      _isAuthenticated = await _authService.isAuthenticated();
    } catch (e) {
      _isAuthenticated = false;
      await _authService.logout();
    }
    setState(() => _isLoading = false);
  }

  void _handleUnauthorized() {
    _authService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
    );

    SnackBarUtil.showError(context, 'Session expired. Please login again.');
  }

  Future<void> _showLogoutDialog() async {
    final navigator = Navigator.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to logout from the Super Admin panel?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  Navigator.of(context).pop();
                  await _authService.logout();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginPage()),
                        (Route<dynamic> route) => false,
                  );
                  SnackBarUtil.showSuccess(context, 'Logged out successfully');
                } catch (e) {
                  SnackBarUtil.showError(context, 'Logout failed. Please try again.');
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _onNavTap(int index) {
    if (index == _navItems.length - 1) {
      _showLogoutDialog();
    } else {
      if (!_isAuthenticated) {
        _handleUnauthorized();
        return;
      }
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: !_isAuthenticated
          ? const Center(
        child: Text(
          'You are not authenticated',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      )
          : _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2ECC71),
        unselectedItemColor: Colors.grey[600],
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onNavTap,
        items: _navItems,
      ),
    );
  }
}