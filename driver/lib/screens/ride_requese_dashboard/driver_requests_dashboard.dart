import 'dart:ui';

import 'package:driver/screens/ride_requese_dashboard/registration_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/driver_requests_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_util.dart';
import '../profile/profile_screen.dart';
import '../profile/recent_bookings_screen.dart';
import '../continue_with_phone.dart';
import 'driver_requests_screen.dart';
import 'mechanic_requests_screen.dart';

class RideRequestsDashboard extends StatefulWidget {
  const RideRequestsDashboard({super.key});
  @override
  _RideRequestsDashboardState createState() => _RideRequestsDashboardState();
}

class _RideRequestsDashboardState extends State<RideRequestsDashboard>
    with TickerProviderStateMixin {
  late AnimationController _refreshController;
  late TabController _tabController;
  String driverStatus = 'pending';
  String mechanicStatus = 'pending';
  bool isLoadingStatus = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Load status first, then initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStatusFromPrefs();

      final provider = Provider.of<DriverRequestsProvider>(
        context,
        listen: false,
      );
      await provider.loadPendingRequests();
      await provider.initializeSocketConnection();
    });
  }

  Future<void> _loadStatusFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverStatus = prefs.getString('driverStatus') ?? 'pending';
      mechanicStatus = prefs.getString('mechanicStatus') ?? 'pending';
      isLoadingStatus = false;
    });

    final approvedTabs = _getApprovedTabs();
    _tabController = TabController(length: approvedTabs.length, vsync: this);
  }

  List<String> _getApprovedTabs() {
    List<String> tabs = [];
    if (driverStatus == 'approved') tabs.add('Driver');
    if (mechanicStatus == 'approved') tabs.add('Mechanic');
    tabs.add('Status');
    return tabs;
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<DriverRequestsProvider>(
      context,
      listen: false,
    );
    provider.setRefreshing(true);

    await provider.loadPendingRequests();
    await _loadStatusFromPrefs(); // Refresh status as well

    provider.setRefreshing(false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DriverRequestsProvider>(context);

    if (isLoadingStatus) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      );
    }

    final approvedTabs = _getApprovedTabs();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Custom Sliver App Bar
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              pinned: true,
              floating: true,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: const Text(
                'Requests Dashboard',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              centerTitle: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.black,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3.0,
                tabs: approvedTabs.map((tab) => Tab(text: tab)).toList(),
              ),
              actions: [
                // Refresh button in app bar
                Consumer<DriverRequestsProvider>(
                  builder: (context, provider, child) {
                    return IconButton(
                      icon: provider.isRefreshing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.black),
                      onPressed: provider.isRefreshing ? null : _handleRefresh,
                    );
                  },
                ),
              ],
            ),
          ];
        },
        body: RefreshIndicator(
          backgroundColor: Colors.white,
          color: Colors.black,
          strokeWidth: 2.5,
          onRefresh: _handleRefresh,
          child: TabBarView(
            controller: _tabController,
            children: _buildTabViews(approvedTabs, provider),
          ),
        ),
      ),
      drawer: _buildDrawer(provider),
    );
  }

  List<Widget> _buildTabViews(
    List<String> approvedTabs,
    DriverRequestsProvider provider,
  ) {
    List<Widget> views = [];

    for (String tab in approvedTabs) {
      if (tab == 'Driver') {
        views.add(
          Consumer<DriverRequestsProvider>(
            builder: (context, provider, child) {
              // Use driverRequests instead of pendingRequests
              if (provider.isRefreshing && provider.driverRequests.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                );
              }
              return NearbyDriverRequestsScreen(provider: provider);
            },
          ),
        );
      } else if (tab == 'Mechanic') {
        views.add(
          Consumer<DriverRequestsProvider>(
            builder: (context, provider, child) {
              // Use mechanicRequests instead of pendingRequests
              if (provider.isRefreshing && provider.mechanicRequests.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                );
              }
              return MechanicRequestsScreen(provider: provider);
            },
          ),
        );
      } else if (tab == 'Status') {
        views.add(
          RegistrationStatusScreen(
            driverStatus: driverStatus,
            mechanicStatus: mechanicStatus,
            onCheckStatus: _loadStatusFromPrefs,
            onGoToServices: () => _tabController.animateTo(0),
          ),
        );
      }
    }

    return views;
  }

  Widget _buildDrawer(DriverRequestsProvider provider) {
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
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.black),
                      title: const Text(
                        "Profile",
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: "UberMove",
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePageScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 0.5),
                    ListTile(
                      leading: const Icon(Icons.history, color: Colors.black),
                      title: const Text(
                        "Recent Bookings",
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: "UberMove",
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecentBookingsPageScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 0.5),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.black),
                      title: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: "UberMove",
                        ),
                      ),
                      onTap: () async {
                        provider.setLoggingOut(true);
                        await Future.delayed(const Duration(milliseconds: 300));

                        try {
                          await Auth.removeToken();
                          provider.disconnectSocket();

                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContinueWithPhone(),
                            ),
                            (route) => false,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          SnackBarUtil.showError(
                            context,
                            'Logout failed: ${e.toString()}',
                          );
                        } finally {
                          if (mounted) {
                            provider.setLoggingOut(false);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 0.5),
              _buildSupportSection(),
            ],
          ),
          if (provider.isLoggingOut)
            Positioned.fill(
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
            ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    const supportPhone = '+92-316-9977808';
    const supportEmail = 'support@myautobridge.com';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need help?',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contact support anytime.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.black87, size: 18),
              const SizedBox(width: 8),
              Text(
                supportPhone,
                style: const TextStyle(
                  color: Colors.black87,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.email, color: Colors.black87, size: 18),
              const SizedBox(width: 8),
              Text(
                supportEmail,
                style: const TextStyle(
                  color: Colors.black87,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
