import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user/screens/services/vehicle_selection_screen.dart';
import '../../providers/home_screen_provider.dart';
import '../../services/auth_service.dart';
import 'package:user/screens/continue_with_phone.dart';
import 'package:user/screens/profile/profile_screen.dart';
import 'package:user/screens/profile/recent_bookings_screen.dart';
import '../services/car_services/car_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.2;
    final imageHeight = cardHeight * 0.9;

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.location_on, color: Colors.black, size: 18),
              SizedBox(width: 5),
              Text(
                "Pakistan",
                style: TextStyle(color: Colors.black, fontFamily: "UberMove"),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePageScreen()),
                );
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey[300],
                radius: 16,
                child: const Icon(Icons.person, color: Colors.black, size: 18),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        drawer: _buildDrawer(context, homeProvider),
        body: _buildBody(context, homeProvider, cardHeight, imageHeight),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, HomeProvider homeProvider) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                alignment: Alignment.center,
                color: Colors.black,
                child: const Text(
                  "MyAutoBridge",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    fontFamily: "UberMove",
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: "Profile",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilePageScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 0.5),
                    _buildDrawerItem(
                      icon: Icons.history,
                      title: "Recent Bookings",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecentBookingsPageScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 0.5),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: "Logout",
                      onTap: () => _handleLogout(context, homeProvider),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (homeProvider.isLoggingOut) _buildLogoutOverlay(),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontFamily: "UberMove",
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _handleLogout(BuildContext context, HomeProvider provider) async {
    provider.setLoggingOut(true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      await Auth.removeToken();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ContinueWithPhone()),
            (route) => false,
      );
    } catch (error) {
      if (context.mounted) {
        _showLogoutError(context);
      }
    } finally {
      if (context.mounted) {
        provider.setLoggingOut(false);
      }
    }
  }

  void _showLogoutError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logout failed. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLogoutOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomeProvider homeProvider,
      double cardHeight, double imageHeight) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBannerSection(homeProvider),
          const SizedBox(height: 20),
          _buildServicesSection(context, cardHeight, imageHeight),
        ],
      ),
    );
  }

  Widget _buildBannerSection(HomeProvider homeProvider) {
    return SizedBox(
      height: 215,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: homeProvider.pageController,
              itemCount: homeProvider.cardTexts.length,
              onPageChanged: homeProvider.onPageChanged,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          homeProvider.cardTexts[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: "UberMove",
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: MediaQuery.of(context).size.height * 0.04,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Find Services",
                              style: TextStyle(fontFamily: "UberMove"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(homeProvider.cardTexts.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: homeProvider.activeIndex == index ? 12 : 8,
                height: homeProvider.activeIndex == index ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: homeProvider.activeIndex == index
                      ? Colors.black
                      : Colors.grey,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context, double cardHeight,
      double imageHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Book a Service",
            style: TextStyle(fontSize: 18, fontFamily: "UberMove"),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildServiceCard(
                context: context,
                cardHeight: cardHeight,
                imageHeight: imageHeight,
                imagePath: 'assets/images/car_service_card.png',
                serviceName: "Car Service",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MechanicServicesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              _buildServiceCard(
                context: context,
                cardHeight: cardHeight,
                imageHeight: imageHeight,
                imagePath: 'assets/images/towing_service.png',
                serviceName: "Towing Service",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VehicleSelectionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Text(
                "Car Service",
                style: TextStyle(fontSize: 16, fontFamily: "UberMove"),
              ),
              SizedBox(width: 25),
              Text(
                "Towing Service",
                style: TextStyle(fontSize: 16, fontFamily: "UberMove"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required double cardHeight,
    required double imageHeight,
    required String imagePath,
    required String serviceName,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: imageHeight,
                child: InkWell(
                  onTap: onTap,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}