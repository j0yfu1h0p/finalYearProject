// screens/cnic_details_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/driver_registration_provider.dart';

class CNICDetailsScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  CNICDetailsScreen({required this.formKey});

  @override
  _CNICDetailsScreenState createState() => _CNICDetailsScreenState();
}

class _CNICDetailsScreenState extends State<CNICDetailsScreen> {
  final ImagePicker _picker = ImagePicker();

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
                'CNIC Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Please provide your CNIC information',
                style: TextStyle(color: Colors.grey[600], fontSize: 14,fontFamily: "UberMove",),
              ),
              SizedBox(height: 24),
              Text(
                'CNIC Number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Enter CNIC number',
                  hintStyle: TextStyle(fontFamily: "UberMove"),
                  errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your CNIC number';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateCnicNumber(value!),
                initialValue: provider.data.cnicNumber,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 32),
              Text(
                'CNIC Front Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              _buildImageUploadCard(
                title: 'Tap to capture front photo',
                image: provider.data.cnicFront,
                onTap: () => _pickImage(provider, 'cnic_front'),
              ),
              SizedBox(height: 24),
              Text(
                'CNIC Back Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              _buildImageUploadCard(
                title: 'Tap to capture back photo',
                image: provider.data.cnicBack,
                onTap: () => _pickImage(provider, 'cnic_back'),
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
          height: 180,
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
                    height: 180,
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 30,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14,fontFamily: "UberMove",),
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
      if (type == 'cnic_front') {
        provider.updateCnicFront(File(image.path));
      } else if (type == 'cnic_back') {
        provider.updateCnicBack(File(image.path));
      }
    }
  }
}
