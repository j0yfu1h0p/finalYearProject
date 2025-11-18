import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../services/auth_service.dart';
import 'car_service.dart';
import 'mechanic_provider.dart';

class ServiceRequestConfirmationScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onCreateRequest;

  const ServiceRequestConfirmationScreen({
    super.key,
    required this.onBack,
    required this.onCreateRequest,
  });

  @override
  State<ServiceRequestConfirmationScreen> createState() =>
      _ServiceRequestConfirmationScreenState();
}

class _ServiceRequestConfirmationScreenState
    extends State<ServiceRequestConfirmationScreen> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final provider = Provider.of<MechanicProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(screenWidth),
              SizedBox(height: screenHeight * 0.02),
              _buildServiceDetailsCard(provider, screenWidth, screenHeight),
              const Spacer(),
              _buildActionButtons(screenHeight, screenWidth),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(double screenWidth) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: screenWidth * 0.06,
          ),
          onPressed: widget.onBack,
        ),
        SizedBox(width: screenWidth * 0.03),
        Text(
          'Service Request Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            fontFamily: 'UberMove',
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetailsCard(
      MechanicProvider provider, double screenWidth, double screenHeight) {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection(
                title: 'Service Type',
                content: provider.selectedService ?? 'No service selected',
                isPrimary: true,
                screenWidth: screenWidth,
              ),
              SizedBox(height: screenHeight * 0.02),
              _buildDivider(),
              SizedBox(height: screenHeight * 0.02),
              _buildDetailSection(
                title: 'Location',
                content: provider.currentLocationAddress ?? 'Location not available',
                isPrimary: false,
                screenWidth: screenWidth,
              ),
              SizedBox(height: screenHeight * 0.02),
              if (provider.notes.isNotEmpty) _buildNotesSection(provider, screenWidth),
              SizedBox(height: screenHeight * 0.02),
              _buildPriceSection(provider, screenWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required String content,
    required bool isPrimary,
    required double screenWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: Colors.grey,
            fontFamily: 'UberMove',
          ),
        ),
        SizedBox(height: screenWidth * 0.01),
        Text(
          content,
          style: TextStyle(
            fontSize: isPrimary ? screenWidth * 0.045 : screenWidth * 0.04,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
            fontFamily: 'UberMove',
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: Colors.grey[800]);
  }

  Widget _buildNotesSection(MechanicProvider provider, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: Colors.grey,
            fontFamily: 'UberMove',
          ),
        ),
        SizedBox(height: screenWidth * 0.01),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            provider.notes,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: Colors.white,
              fontFamily: 'UberMove',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection(MechanicProvider provider, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimated Price',
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: Colors.grey,
            fontFamily: 'UberMove',
          ),
        ),
        SizedBox(height: screenWidth * 0.01),
        Text(
          'PKR ${provider.calculatedPrice?.toStringAsFixed(2) ?? 'N/A'}',
          style: TextStyle(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'UberMove',
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(double screenHeight, double screenWidth) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: widget.onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              textStyle: TextStyle(
                fontFamily: 'UberMove',
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          child: ElevatedButton(
            onPressed: widget.onCreateRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              textStyle: TextStyle(
                fontFamily: 'UberMove',
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
            ),
            child: const Text('Confirm Request'),
          ),
        ),
      ],
    );
  }
}