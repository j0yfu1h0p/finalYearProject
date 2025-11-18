// screens/basic_info_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/driver_registration_provider.dart';

class BasicInfoScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  BasicInfoScreen({required this.formKey});

  @override
  _BasicInfoScreenState createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final ImagePicker _picker = ImagePicker();
  TextEditingController _dobController = TextEditingController();

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
                'Personal Information',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Please provide your basic information',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Stack(
                        children: [
                          if (provider.data.profilePhoto != null)
                            ClipOval(
                              child: Image.file(
                                provider.data.profilePhoto!,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                              ),
                            ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(60),
                                onTap: () => _pickImage(provider),
                                child: provider.data.profilePhoto == null
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              size: 30,
                                              color: Colors.grey[600],
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add Photo',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Profile Photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: "UberMove",
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              Text(
                'First Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(hintText: 'Enter your first name',hintStyle: TextStyle(fontFamily: "UberMove"),errorStyle: TextStyle(fontFamily: "UberMove")),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateFirstName(value!),
                initialValue: provider.data.firstName,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Last Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove"
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(hintText: 'Enter your last name',hintStyle: TextStyle(fontFamily: "UberMove"),errorStyle: TextStyle(fontFamily: "UberMove")),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
                onSaved: (value) => provider.updateLastName(value!),
                initialValue: provider.data.lastName,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Date of Birth',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Select your date of birth',hintStyle: TextStyle(fontFamily: "UberMove"),errorStyle: TextStyle(fontFamily: "UberMove"),
                  suffixIcon: Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, provider),
                controller: _dobController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your date of birth';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "UberMove",
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Enter your email (optional)',hintStyle: TextStyle(fontFamily: "UberMove"),errorStyle: TextStyle(fontFamily: "UberMove"),
                ),
                keyboardType: TextInputType.emailAddress,
                onSaved: (value) => provider.updateEmail(value ?? ''),
                initialValue: provider.data.email,
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(RegistrationProvider provider) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      provider.updateProfilePhoto(File(image.path));
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    RegistrationProvider provider,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.updateDateOfBirth(picked);
      _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
    }
  }
}
