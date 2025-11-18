import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:user/screens/services/car_services/service_request_confirmation_screen.dart';
import 'dart:convert';

import '../../../services/auth_service.dart';
import 'mechanic_provider.dart';
import 'mechanic_socket_service.dart';
import 'mechanic_tracking_scree.dart';

class WaitingForMechanicScreen extends StatefulWidget {
  final String requestId;
  final String serviceType;
  final VoidCallback onCancel;

  const WaitingForMechanicScreen({
    super.key,
    required this.requestId,
    required this.serviceType,
    required this.onCancel,
  });

  @override
  State<WaitingForMechanicScreen> createState() => _WaitingForMechanicScreenState();
}

class _WaitingForMechanicScreenState extends State<WaitingForMechanicScreen> {
  bool _mechanicAssigned = false;
  Map<String, dynamic>? _mechanicData;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() async {
    await MechanicSocketService.initializeSocket();

    MechanicSocketService.joinRequestRoom(widget.requestId);

    MechanicSocketService.socket?.on('mechanic_assigned', (data) {
      if (mounted) {
        setState(() {
          _mechanicAssigned = true;
          _mechanicData = data['mechanic'];
        });
        _navigateToMechanicTracking(data);
      }
    });

    MechanicSocketService.socket?.on('request_timeout', (data) {
      if (mounted) {
        _showTimeoutDialog();
      }
    });

    MechanicSocketService.socket?.on('mechanic_request_update', (data) {
      if (mounted) {
        setState(() {
          _mechanicAssigned = true;
          _mechanicData = data['mechanic'];
        });
        _navigateToMechanicTracking(data);
      }
    });
  }

  void _navigateToMechanicTracking(Map<String, dynamic> data) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MechanicTrackingScreen(
          mechanicData: data['mechanic'],
          serviceRequest: data['requestData'],
          routeData: {},
        ),
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'No Mechanics Available',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Sorry, no mechanics are currently available. Please try again later.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCancel();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    MechanicSocketService.socket?.off('mechanic_assigned');
    MechanicSocketService.socket?.off('request_timeout');
    MechanicSocketService.socket?.off('mechanic_request_update');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(flex: 2),
            Icon(Icons.build, color: Colors.white, size: screenHeight * 0.12),
            SizedBox(height: screenHeight * 0.03),
            const Text(
              'Looking for a mechanic',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'UberMove',
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'Service: ${widget.serviceType}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontFamily: 'UberMove',
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'Request ID: ${widget.requestId}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'UberMove',
              ),
            ),
            Spacer(),
            const CircularProgressIndicator(color: Colors.green),
            SizedBox(height: screenHeight * 0.02),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: const Text(
                'Please wait while we find the nearest available mechanic...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'UberMove',
                ),
              ),
            ),
            Spacer(flex: 3),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: ElevatedButton(
                onPressed: widget.onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  textStyle: const TextStyle(
                    fontFamily: 'UberMove',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Cancel Request',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: screenWidth * 0.04),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MechanicAssignedScreen extends StatelessWidget {
  final Map<String, dynamic> mechanicDetails;
  final String serviceType;
  final double price;
  final String location;
  final String notes;

  const MechanicAssignedScreen({
    super.key,
    required this.mechanicDetails,
    required this.serviceType,
    required this.price,
    required this.location,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mechanic Assigned',
          style: TextStyle(color: Colors.white, fontFamily: 'UberMove'),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your mechanic is on the way!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'UberMove',
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'ETA: ${mechanicDetails['eta'] ?? 'Unknown'}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontFamily: 'UberMove',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mechanic Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: screenWidth * 0.07,
                            backgroundColor: Colors.grey,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: screenWidth * 0.07,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mechanicDetails['name'] ?? 'Unknown Mechanic',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    SizedBox(width: screenWidth * 0.01),
                                    Text(
                                      '${mechanicDetails['rating'] ?? '0.0'} (${mechanicDetails['reviews'] ?? '0'} reviews)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'UberMove',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      const Text(
                        'Vehicle Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: screenWidth * 0.05),
                          SizedBox(width: screenWidth * 0.03),
                          Text(
                            '${mechanicDetails['vehicle'] ?? 'Unknown Vehicle'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'UberMove',
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.05),
                          Icon(Icons.confirmation_number, size: screenWidth * 0.05),
                          SizedBox(width: screenWidth * 0.03),
                          Text(
                            '${mechanicDetails['plateNumber'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.03),

                      const Text(
                        'Service Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'UberMove',
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Service Type:',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'UberMove',
                            ),
                          ),
                          Text(
                            serviceType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Price:',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'UberMove',
                            ),
                          ),
                          Text(
                            'PKR ${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location:',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'UberMove',
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: Text(
                              location,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (notes.isNotEmpty) ...[
                        SizedBox(height: screenHeight * 0.01),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes:',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'UberMove',
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Text(
                                notes,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'UberMove',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: screenHeight * 0.03),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.02,
                                ),
                              ),
                              icon: const Icon(Icons.phone),
                              label: Text(
                                'Call Mechanic',
                                style: TextStyle(
                                  fontFamily: 'UberMove',
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.02,
                                ),
                              ),
                              icon: const Icon(Icons.message),
                              label: Text(
                                'Message',
                                style: TextStyle(
                                  fontFamily: 'UberMove',
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}