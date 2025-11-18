// screens/vehicle_info_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/driver_registration_provider.dart';

class VehicleInfoScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  VehicleInfoScreen({required this.formKey});

  @override
  _VehicleInfoScreenState createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> vehicleTypes = [
    'Flatbed',
    'Wheel-Lift',
    'Integrated (Repo)',
    'Hook & Chain',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RegistrationProvider>(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle Information',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Please provide your vehicle details',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Vehicle Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select vehicle type',
                  hintStyle: TextStyle(color: Colors.grey[600],fontFamily: "UberMove"),

                  errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                value: provider.data.vehicleType,
                items: vehicleTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: "UberMove",
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  provider.updateVehicleType(newValue ?? '');
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select vehicle type';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateVehicleType(value ?? ''),
                style: TextStyle(color: Colors.black),
                dropdownColor: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Company & Model',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'e.g., United Bravo',
                  hintStyle: TextStyle(fontFamily: "UberMove"),
                  errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter company and model';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateCompanyModel(value!),
                initialValue: provider.data.companyModel,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Vehicle Color',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'e.g., Black',
                  hintStyle: TextStyle(fontFamily: "UberMove"),
                  errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle color';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateVehicleColor(value!),
                initialValue: provider.data.vehicleColor,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Number Plate',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Enter plate number',
                  hintStyle: TextStyle(fontFamily: "UberMove"),
                  errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number plate';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateNumberPlate(value!),
                initialValue: provider.data.numberPlate,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Manufacturing Year',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Enter manufacturing year',
                  hintStyle: TextStyle(fontFamily: "UberMove"),
                  errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter manufacturing year';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateManufacturingYear(value!),
                initialValue: provider.data.manufacturingYear,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 32),
              Text(
                'Vehicle Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              _buildImageUploadCard(
                title: 'Tap to capture vehicle photo',
                image: provider.data.vehiclePhoto,
                onTap: () => _pickImage(provider, 'vehicle'),
              ),
              SizedBox(height: 24),
              Text(
                'Registration Certificate (Front)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              _buildImageUploadCard(
                title: 'Tap to capture front',
                image: provider.data.registrationFront,
                onTap: () => _pickImage(provider, 'reg_front'),
              ),
              SizedBox(height: 24),
              Text(
                'Registration Certificate (Back)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              _buildImageUploadCard(
                title: 'Tap to capture back',
                image: provider.data.registrationBack,
                onTap: () => _pickImage(provider, 'reg_back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    File? image,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 160,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 160,
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 24,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontFamily: "UberMove",
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(RegistrationProvider provider, String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      switch (type) {
        case 'vehicle':
          provider.updateVehiclePhoto(File(image.path));
          break;
        case 'reg_front':
          provider.updateRegistrationFront(File(image.path));
          break;
        case 'reg_back':
          provider.updateRegistrationBack(File(image.path));
          break;
      }
    }
  }
}
