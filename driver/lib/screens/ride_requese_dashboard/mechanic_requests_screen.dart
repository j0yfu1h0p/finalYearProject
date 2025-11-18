import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mechanic_service_request_model.dart';
import '../../providers/driver_requests_provider.dart';
import 'mechanic_request_card.dart';
import 'user_track_screen_mech.dart';

class MechanicRequestsScreen extends StatelessWidget {
  final DriverRequestsProvider provider;

  const MechanicRequestsScreen({super.key, required this.provider});

  void _handleAcceptMechanic(MechanicServiceRequest request, BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      );

      // Accept the mechanic request
      await provider.acceptMechanicRequest(request.id);

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mechanic request accepted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to the UserTrackScreenMech after successful acceptance
      _navigateToTrackingScreen(request, context);

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept mechanic request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToTrackingScreen(MechanicServiceRequest request, BuildContext context) {
    // Use actual data from the request
    final mechanicData = {
      '_id': 'current_mechanic_id', // You'll need to get the actual mechanic ID
      'name': 'Mechanic Name', // You'll need to get the actual mechanic name
    };

    final serviceRequestData = {
      '_id': request.id,
      'serviceType': request.serviceType,
      'notes': request.notes,
      'userLocation': {
        'coordinates': request.userLocation.coordinates,
      },
      'priceQuote': {
        'amount': request.priceQuote?.amount ?? 0, // Use actual price quote amount
        'currency': request.priceQuote?.currency ?? 'PKR',
      },
    };

    final userData = {
      '_id': request.userId, // Use actual user ID from the request
      'name': 'Customer', // You might want to get the actual user name from your API
      'phone': '+1234567890', // You might want to get the actual user phone from your API
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserTrackScreenMech(
          mechanicData: mechanicData,
          serviceRequest: serviceRequestData,
          userData: userData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(provider),
        Expanded(child: _buildMechanicRequestsList(context, provider)),
      ],
    );
  }

  Widget _buildHeader(DriverRequestsProvider provider) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE MECHANIC REQUESTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${provider.mechanicRequests.length} Requests',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => provider.loadMechanicRequests(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicRequestsList(BuildContext context, DriverRequestsProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Error loading requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadMechanicRequests(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.mechanicRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No mechanic requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'New mechanic service requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: provider.mechanicRequests.length,
      itemBuilder: (context, index) {
        final request = provider.mechanicRequests[index];

        // Extract coordinates from request
        final coordinates = request.userLocation.coordinates;
        final double longitude = coordinates[0];
        final double latitude = coordinates[1];

        // Use actual price quote from the request
        String fare = "Rs. ${request.priceQuote?.amount ?? 0}";

        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 8),
          child: MechanicRequestCard(
            requestId: '#${request.id.substring(request.id.length - 6)}',
            serviceType: request.serviceType,
            notes: request.notes,
            latitude: latitude,
            longitude: longitude,
            fare: fare,
            onAccept: () => _handleAcceptMechanic(request, context),
          ),
        );
      },
    );
  }
}