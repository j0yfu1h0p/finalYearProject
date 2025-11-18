// import 'package:driver/screens/profile/profile_screen.dart';
// import 'package:driver/screens/profile/recent_bookings_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:ui';
// import '../models/driver_request_screen_model.dart';
// import '../models/mechanic_service_request_model.dart';
// import '../providers/driver_requests_provider.dart';
// import '../services/auth_service.dart';
// import 'PassengerDetailsScreen.dart';
// import 'continue_with_phone.dart';
//
// class RideRequestsDashboard extends StatefulWidget {
//   const RideRequestsDashboard({super.key});
//   @override
//   _RideRequestsDashboardState createState() => _RideRequestsDashboardState();
// }
//
// class _RideRequestsDashboardState extends State<RideRequestsDashboard>
//     with TickerProviderStateMixin {
//   late AnimationController _refreshController;
//   late Animation<double> _refreshAnimation;
//   late TabController _tabController;
//   String driverStatus = 'pending';
//   String mechanicStatus = 'pending';
//   bool isLoadingStatus = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _refreshController = AnimationController(
//       duration: const Duration(milliseconds: 1500),
//       vsync: this,
//     );
//     _refreshAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _refreshController, curve: Curves.elasticOut),
//     );
//
//     _loadStatusFromPrefs();
//
//
//     final provider = Provider.of<DriverRequestsProvider>(context, listen: false);
//     provider.loadPendingRequests();
//     provider.initializeSocketConnection();
//
//   }
//
//   Future<void> _loadStatusFromPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       driverStatus = prefs.getString('driverStatus') ?? 'pending';
//       mechanicStatus = prefs.getString('mechanicStatus') ?? 'pending';
//       isLoadingStatus = false;
//     });
//
//     // Initialize tab controller with the correct number of tabs
//     final approvedTabs = _getApprovedTabs();
//     _tabController = TabController(length: approvedTabs.length, vsync: this);
//   }
//
//   List<String> _getApprovedTabs() {
//     List<String> tabs = [];
//     if (driverStatus == 'approved') tabs.add('Driver');
//     if (mechanicStatus == 'approved') tabs.add('Mechanic');
//     tabs.add('Status');
//     return tabs;
//   }
//
//   @override
//   void dispose() {
//     _refreshController.dispose();
//     _tabController.dispose();
//     super.dispose();
//   }
//
//   void _handleRefresh() async {
//     final provider = Provider.of<DriverRequestsProvider>(context, listen: false);
//     provider.setRefreshing(true);
//     _refreshController.forward();
//
//     await provider.loadPendingRequests();
//
//     _refreshController.reverse();
//     provider.setRefreshing(false);
//   }
//
//   void _handleAcceptDriver(ServiceRequest request) async {
//     final provider = Provider.of<DriverRequestsProvider>(context, listen: false);
//
//     try {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => const Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//           ),
//         ),
//       );
//
//       await provider.acceptDriverRequest(request.id);
//
//       Navigator.pop(context); // Close loading dialog
//
//       // Join the trip room for real-time updates
//       provider.socketService.joinDriverTracking(request.id);
//
//       // Navigate with socket service instance
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (context) => SimplePassengerDetailsScreen(
//             request: request,
//             socketService: provider.socketService,
//           ),
//         ),
//             (Route<dynamic> route) => false,
//       );
//     } catch (e) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to accept request: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void _handleAcceptMechanic(MechanicServiceRequest request) async {
//     final provider = Provider.of<DriverRequestsProvider>(context, listen: false);
//
//     try {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => const Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//           ),
//         ),
//       );
//
//       await provider.acceptMechanicRequest(request.id);
//
//       Navigator.pop(context); // Close loading dialog
//
//       // For mechanic requests, you might want to navigate to a different screen
//       // For now, let's just show a success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Mechanic request accepted successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to accept mechanic request: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final provider = Provider.of<DriverRequestsProvider>(context);
//
//     if (isLoadingStatus) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//           ),
//         ),
//       );
//     }
//
//     final approvedTabs = _getApprovedTabs();
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: Builder(
//           builder: (context) => IconButton(
//             icon: const Icon(Icons.menu, color: Colors.black),
//             onPressed: () => Scaffold.of(context).openDrawer(),
//           ),
//         ),
//         title: const Text(
//           'Requests Dashboard',
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 18,
//             fontWeight: FontWeight.w700,
//             letterSpacing: 0.5,
//           ),
//         ),
//         centerTitle: true,
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.black,
//           labelColor: Colors.black,
//           unselectedLabelColor: Colors.grey,
//           tabs: approvedTabs.map((tab) => Tab(text: tab)).toList(),
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: _buildTabViews(approvedTabs, provider),
//       ),
//       drawer: _buildDrawer(provider),
//     );
//   }
//
//   List<Widget> _buildTabViews(List<String> approvedTabs, DriverRequestsProvider provider) {
//     List<Widget> views = [];
//
//     for (String tab in approvedTabs) {
//       if (tab == 'Driver') {
//         views.add(
//             Column(
//               children: [
//                 _buildHeader(provider, 'Driver'),
//                 Expanded(child: _buildDriverRequestsList(provider)),
//               ],
//             )
//         );
//       } else if (tab == 'Mechanic') {
//         views.add(
//             Column(
//               children: [
//                 _buildHeader(provider, 'Mechanic'),
//                 Expanded(child: _buildMechanicRequestsList(provider)),
//               ],
//             )
//         );
//       } else if (tab == 'Status') {
//         views.add(_buildRegistrationStatusScreen());
//       }
//     }
//
//     return views;
//   }
//
//   Widget _buildHeader(DriverRequestsProvider provider, String type) {
//     final requestCount = type == 'Driver'
//         ? provider.driverRequests.length
//         : provider.mechanicRequests.length;
//
//     return Container(
//       margin: const EdgeInsets.all(12),
//       child: Column(
//         children: [
//           const SizedBox(height: 8),
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey[300]!, width: 1),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'AVAILABLE ${type.toUpperCase()} REQUESTS',
//                       style: TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.grey,
//                         letterSpacing: 1,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Row(
//                       children: [
//                         Container(
//                           width: 6,
//                           height: 6,
//                           decoration: const BoxDecoration(
//                             color: Colors.black,
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           '$requestCount Requests',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.black,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     if (type == 'Driver') {
//                       provider.loadDriverRequests();
//                     } else {
//                       provider.loadMechanicRequests();
//                     }
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.black,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.refresh,
//                       color: Colors.white,
//                       size: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDriverRequestsList(DriverRequestsProvider provider) {
//     if (provider.isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//         ),
//       );
//     }
//
//     if (provider.errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.red, size: 48),
//             const SizedBox(height: 16),
//             const Text(
//               'Error loading requests',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.red,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               provider.errorMessage!,
//               style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => provider.loadDriverRequests(),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.black,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     if (provider.driverRequests.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
//             SizedBox(height: 16),
//             Text(
//               'No pending requests',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'New ride requests will appear here',
//               style: TextStyle(fontSize: 14, color: Colors.grey),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return ListView.builder(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       itemCount: provider.driverRequests.length,
//       itemBuilder: (context, index) {
//         final request = provider.driverRequests[index];
//         return AnimatedContainer(
//           duration: Duration(milliseconds: 300 + (index * 100)),
//           curve: Curves.easeOutCubic,
//           margin: const EdgeInsets.only(bottom: 8),
//           child: RequestCard(
//             requestId: '#${request.id.substring(request.id.length - 6)}',
//             pickupLocation: request.pickupLocation.address,
//             destination: request.destination.address,
//             distance: '${request.distance.toStringAsFixed(1)} km',
//             fare: 'Rs. ${request.totalAmount.toStringAsFixed(0)}',
//             estimatedTime: '${request.duration} min',
//             passengerRating: 4.5,
//             onAccept: () => _handleAcceptDriver(request),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildMechanicRequestsList(DriverRequestsProvider provider) {
//     if (provider.isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//         ),
//       );
//     }
//
//     if (provider.errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.red, size: 48),
//             const SizedBox(height: 16),
//             const Text(
//               'Error loading requests',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.red,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               provider.errorMessage!,
//               style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => provider.loadMechanicRequests(),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.black,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     if (provider.mechanicRequests.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
//             SizedBox(height: 16),
//             Text(
//               'No mechanic requests',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'New mechanic service requests will appear here',
//               style: TextStyle(fontSize: 14, color: Colors.grey),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return ListView.builder(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       itemCount: provider.mechanicRequests.length,
//       itemBuilder: (context, index) {
//         final request = provider.mechanicRequests[index];
//         return AnimatedContainer(
//           duration: Duration(milliseconds: 300 + (index * 100)),
//           curve: Curves.easeOutCubic,
//           margin: const EdgeInsets.only(bottom: 8),
//           child: MechanicRequestCard(
//             requestId: '#${request.id.substring(request.id.length - 6)}',
//             serviceType: request.serviceType,
//             notes: request.notes,
//             distance: '2.3 km', // You'll need to calculate this based on location
//             fare: 'Rs. 1200', // You'll need to get this from the API or calculate it
//             estimatedTime: '15 min', // You'll need to calculate this
//             onAccept: () => _handleAcceptMechanic(request),
//           ),
//         );
//       },
//     );
//   }
//
//   // Registration Status Screen
//   Widget _buildRegistrationStatusScreen() {
//     final statuses = {
//       'driver': driverStatus,
//       'mechanic': mechanicStatus,
//     };
//
//     // Filter only valid statuses
//     final statusEntries = statuses.entries
//         .where((entry) => entry.value != null && entry.value != 'not_registered')
//         .toList();
//
//     // Determine if any role is approved
//     bool anyApproved = statusEntries.any((entry) => entry.value == 'approved');
//
//     return WillPopScope(
//       onWillPop: () async => false,
//       child: Scaffold(
//         backgroundColor: Colors.grey[50],
//         body: Stack(
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 8),
//
//                   // Instruction
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(12),
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: Colors.yellow[100],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'If your requested role/status is not showing here, please log out and log in again to refresh your account.',
//                       style: TextStyle(fontSize: 14, color: Colors.black87, fontFamily: "UberMove"),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//
//                   const Text(
//                     'Your registration status',
//                     style: TextStyle(fontSize: 16, color: Colors.black54, fontFamily: "UberMove"),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Expanded list of status cards
//                   Expanded(
//                     child: ListView.separated(
//                       itemCount: statusEntries.length,
//                       separatorBuilder: (context, index) => const SizedBox(height: 16),
//                       itemBuilder: (context, index) {
//                         final entry = statusEntries[index];
//                         final display = _getStatusDisplay(entry.value);
//                         if (display == null) return const SizedBox.shrink();
//
//                         final role = entry.key;
//                         final status = entry.value;
//
//                         return Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(16),
//                             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
//                           ),
//                           child: Padding(
//                             padding: const EdgeInsets.all(20),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(role.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54, fontFamily: "UberMove")),
//                                 const SizedBox(height: 16),
//                                 Row(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Container(
//                                       padding: const EdgeInsets.all(8),
//                                       decoration: BoxDecoration(color: display['color'].withOpacity(0.1), shape: BoxShape.circle),
//                                       child: Icon(display['icon'], size: 28, color: display['color']),
//                                     ),
//                                     const SizedBox(width: 16),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Text(display['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: display['color'], fontFamily: "UberMove")),
//                                           const SizedBox(height: 4),
//                                           Text(display['message'], style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: "UberMove")),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 16),
//                                 Text(display['details'], style: const TextStyle(fontSize: 14, color: Colors.black54, fontFamily: "UberMove", height: 1.4)),
//                                 const SizedBox(height: 16),
//
//                                 if (status == 'rejected') ...[
//                                   const Divider(height: 1),
//                                   const SizedBox(height: 16),
//                                   const Text('Need help? Contact our support team:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "UberMove")),
//                                   const SizedBox(height: 12),
//                                   Row(
//                                     children: [
//                                       Icon(Icons.phone, color: Colors.green[700], size: 20),
//                                       const SizedBox(width: 8),
//                                       Text('+92-316-9977808', style: TextStyle(fontSize: 14, color: Colors.green[700], fontFamily: "UberMove")),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Row(
//                                     children: [
//                                       Icon(Icons.email, color: Colors.green[700], size: 20),
//                                       const SizedBox(width: 8),
//                                       Text('support@myautobridge.com', style: TextStyle(fontSize: 14, color: Colors.green[700], fontFamily: "UberMove")),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 16),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//
//                   // Button(s) at the bottom
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: anyApproved
//                           ? () {
//                         // Go to the first tab (which should be an approved service)
//                         _tabController.animateTo(0);
//                       }
//                           : _checkStatusAgain,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: anyApproved ? Colors.green : Colors.white,
//                         foregroundColor: anyApproved ? Colors.white : Colors.green,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           side: anyApproved ? BorderSide.none : BorderSide(color: Colors.green),
//                         ),
//                         elevation: 0,
//                       ),
//                       child: Text(
//                         anyApproved ? 'Go to Services' : 'Check Status Again',
//                         style: const TextStyle(fontSize: 16, fontFamily: "UberMove", fontWeight: FontWeight.w500),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// Maps status to icon, color, and default messages
//   /// Returns null if the status is not recognized
//   Map<String, dynamic>? _getStatusDisplay(String status) {
//     switch (status) {
//       case 'pending':
//         return {
//           'icon': Icons.hourglass_top_rounded,
//           'color': Colors.orange,
//           'title': 'Pending Review',
//           'message': 'Your registration is under review',
//           'details': 'We will notify you once approved. This process typically takes 24-48 hours.'
//         };
//       case 'approved':
//         return {
//           'icon': Icons.check_circle_rounded,
//           'color': Colors.green,
//           'title': 'Approved',
//           'message': 'Your registration was approved',
//           'details': 'You can now start accepting requests.'
//         };
//       case 'rejected':
//         return {
//           'icon': Icons.error_outline_rounded,
//           'color': Colors.red,
//           'title': 'Registration Rejected',
//           'message': 'Your registration was not approved',
//           'details': 'Please contact support for more information.'
//         };
//       default:
//         return null; // unknown statuses will be ignored
//     }
//   }
//
//   /// Re-check registration status
//   void _checkStatusAgain() {
//     // This would typically involve re-fetching status from the server
//     // For now, we'll just reload the status from SharedPreferences
//     _loadStatusFromPrefs();
//   }
//
//   Widget _buildDrawer(DriverRequestsProvider provider) {
//     return Drawer(
//       backgroundColor: Colors.white,
//       child: Stack(
//         children: [
//           Column(
//             children: [
//               Container(
//                 height: 200,
//                 width: double.infinity,
//                 alignment: Alignment.center,
//                 color: Colors.black,
//                 child: const Text(
//                   "MyAutoBridge",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 30,
//                     fontWeight: FontWeight.bold,
//                     fontFamily: "UberMove",
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     ListTile(
//                       leading: const Icon(Icons.person, color: Colors.black),
//                       title: const Text(
//                         "Profile",
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontFamily: "UberMove",
//                         ),
//                       ),
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => ProfilePageScreen(),
//                           ),
//                         );
//                       },
//                     ),
//                     const Divider(height: 0.5),
//                     ListTile(
//                       leading: const Icon(Icons.history, color: Colors.black),
//                       title: const Text(
//                         "Recent Bookings",
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontFamily: "UberMove",
//                         ),
//                       ),
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => RecentBookingsPageScreen(),
//                           ),
//                         );
//                       },
//                     ),
//                     const Divider(height: 0.5),
//                     ListTile(
//                       leading: const Icon(Icons.logout, color: Colors.black),
//                       title: const Text(
//                         "Logout",
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontFamily: "UberMove",
//                         ),
//                       ),
//                       onTap: () async {
//                         provider.setLoggingOut(true);
//                         await Future.delayed(const Duration(milliseconds: 300));
//
//                         try {
//                           await Auth.removeToken();
//                           provider.disconnectSocket();
//
//                           if (!mounted) return;
//                           Navigator.pushAndRemoveUntil(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => ContinueWithPhone(),
//                             ),
//                                 (route) => false,
//                           );
//                         } catch (e) {
//                           if (!mounted) return;
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('Logout failed: ${e.toString()}'),
//                             ),
//                           );
//                         } finally {
//                           if (mounted) {
//                             provider.setLoggingOut(false);
//                           }
//                         }
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           if (provider.isLoggingOut)
//             Positioned.fill(
//               child: BackdropFilter(
//                 filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
//                 child: Container(
//                   color: Colors.black.withOpacity(0.3),
//                   child: const Center(
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//                       strokeWidth: 3,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
// // RequestCard widget remains the same as in your original code
// class RequestCard extends StatefulWidget {
//   final String requestId;
//   final String pickupLocation;
//   final String destination;
//   final String distance;
//   final String fare;
//   final String estimatedTime;
//   final double passengerRating;
//   final VoidCallback onAccept;
//
//   const RequestCard({
//     Key? key,
//     required this.requestId,
//     required this.pickupLocation,
//     required this.destination,
//     required this.distance,
//     required this.fare,
//     required this.estimatedTime,
//     required this.passengerRating,
//     required this.onAccept,
//   }) : super(key: key);
//
//   @override
//   _RequestCardState createState() => _RequestCardState();
// }
//
// class _RequestCardState extends State<RequestCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _cardController;
//   late Animation<double> _cardAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     _cardController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _cardAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
//     );
//     _cardController.forward();
//   }
//
//   @override
//   void dispose() {
//     _cardController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _cardAnimation,
//       builder: (context, child) {
//         final double opacityValue = _cardAnimation.value.clamp(0.0, 1.0);
//         return Transform.scale(
//           scale: _cardAnimation.value,
//           child: Opacity(
//             opacity: opacityValue,
//             child: Container(
//               constraints: BoxConstraints(
//                 maxWidth: MediaQuery.of(context).size.width * 0.9,
//               ),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.1),
//                     spreadRadius: 1,
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   _buildCardHeader(),
//                   _buildLocationInfo(),
//                   _buildTripDetails(),
//                   _buildActionButtons(),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildCardHeader() {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Text(
//                 widget.requestId,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.black,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               const Text(
//                 'PASSENGER',
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.grey,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//             decoration: BoxDecoration(
//               color: Colors.green,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Text(
//               widget.fare,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.white,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLocationInfo() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       child: Column(
//         children: [
//           _buildLocationRow(
//             Icons.location_on,
//             widget.pickupLocation,
//             Colors.redAccent,
//             'PICKUP',
//           ),
//           Container(
//             margin: const EdgeInsets.symmetric(vertical: 4),
//             child: Row(
//               children: [
//                 const SizedBox(width: 18),
//                 Container(width: 2, height: 16, color: Colors.grey),
//                 const SizedBox(width: 12),
//                 Expanded(child: Container(height: 1, color: Colors.grey)),
//               ],
//             ),
//           ),
//           _buildLocationRow(
//             Icons.flag,
//             widget.destination,
//             Colors.black,
//             'DESTINATION',
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLocationRow(
//       IconData icon,
//       String location,
//       Color color,
//       String label,
//       ) {
//     return Row(
//       children: [
//         Icon(icon, color: color, size: 14),
//         const SizedBox(width: 10),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.grey,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 1),
//               Text(
//                 location,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTripDetails() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       padding: const EdgeInsets.all(6),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[300]!, width: 1),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _buildDetailItem(Icons.straighten, widget.distance, 'DISTANCE'),
//           _buildDetailItem(Icons.schedule, widget.estimatedTime, 'DURATION'),
//           _buildDetailItem(Icons.directions_car, 'SEDAN', 'VEHICLE'),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailItem(IconData icon, String value, String label) {
//     return Column(
//       children: [
//         Icon(icon, color: Colors.black, size: 12),
//         const SizedBox(height: 2),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w700,
//             color: Colors.black,
//           ),
//         ),
//         const SizedBox(height: 1),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 8,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//             letterSpacing: 0.5,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildActionButtons() {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       child: Row(
//         children: [
//           Expanded(
//             child: GestureDetector(
//               onTap: widget.onAccept,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.black,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Center(
//                   child: Text(
//                     'ACCEPT',
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.white,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class MechanicRequestCard extends StatefulWidget {
//   final String requestId;
//   final String serviceType;
//   final String notes;
//   final String distance;
//   final String fare;
//   final String estimatedTime;
//   final VoidCallback onAccept;
//
//   const MechanicRequestCard({
//     Key? key,
//     required this.requestId,
//     required this.serviceType,
//     required this.notes,
//     required this.distance,
//     required this.fare,
//     required this.estimatedTime,
//     required this.onAccept,
//   }) : super(key: key);
//
//   @override
//   _MechanicRequestCardState createState() => _MechanicRequestCardState();
// }
//
// class _MechanicRequestCardState extends State<MechanicRequestCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _cardController;
//   late Animation<double> _cardAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     _cardController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _cardAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
//     );
//     _cardController.forward();
//   }
//
//   @override
//   void dispose() {
//     _cardController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _cardAnimation,
//       builder: (context, child) {
//         final double opacityValue = _cardAnimation.value.clamp(0.0, 1.0);
//         return Transform.scale(
//           scale: _cardAnimation.value,
//           child: Opacity(
//             opacity: opacityValue,
//             child: Container(
//               constraints: BoxConstraints(
//                 maxWidth: MediaQuery.of(context).size.width * 0.9,
//               ),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.1),
//                     spreadRadius: 1,
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   _buildCardHeader(),
//                   _buildServiceInfo(),
//                   _buildTripDetails(),
//                   _buildActionButtons(),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildCardHeader() {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Text(
//                 widget.requestId,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.black,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               const Text(
//                 'MECHANIC SERVICE',
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.grey,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//             decoration: BoxDecoration(
//               color: Colors.blue,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Text(
//               widget.fare,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.white,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildServiceInfo() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       child: Column(
//         children: [
//           _buildInfoRow(
//             Icons.build,
//             widget.serviceType,
//             Colors.blue,
//             'SERVICE TYPE',
//           ),
//           const SizedBox(height: 8),
//           _buildInfoRow(
//             Icons.note,
//             widget.notes,
//             Colors.grey,
//             'NOTES',
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoRow(
//       IconData icon,
//       String text,
//       Color color,
//       String label,
//       ) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Icon(icon, color: color, size: 14),
//         const SizedBox(width: 10),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.grey,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 1),
//               Text(
//                 text,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTripDetails() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       padding: const EdgeInsets.all(6),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[300]!, width: 1),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _buildDetailItem(Icons.straighten, widget.distance, 'DISTANCE'),
//           _buildDetailItem(Icons.schedule, widget.estimatedTime, 'EST. TIME'),
//           _buildDetailItem(Icons.directions_car, 'MECHANIC', 'SERVICE'),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailItem(IconData icon, String value, String label) {
//     return Column(
//       children: [
//         Icon(icon, color: Colors.black, size: 12),
//         const SizedBox(height: 2),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w700,
//             color: Colors.black,
//           ),
//         ),
//         const SizedBox(height: 1),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 8,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//             letterSpacing: 0.5,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildActionButtons() {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       child: Row(
//         children: [
//           Expanded(
//             child: GestureDetector(
//               onTap: widget.onAccept,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.black,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Center(
//                   child: Text(
//                     'ACCEPT',
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.white,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
//
