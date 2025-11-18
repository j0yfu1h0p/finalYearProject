// screens/registration_stepper.dart
import 'package:driver/screens/driver_registration/screens/vehicle_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/driver_registration_provider.dart';
import 'basic_info_screen.dart';
import 'cnic_details_screen.dart';
import 'driver_license_screen.dart';

class RegistrationStepper extends StatefulWidget {
  @override
  _RegistrationStepperState createState() => _RegistrationStepperState();
}

class _RegistrationStepperState extends State<RegistrationStepper> {
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  List<String> stepTitles = ['Basic Info', 'CNIC', 'License', 'Vehicle'];
  void _submitRegistration(BuildContext context, GlobalKey<FormState> formKey) {
    final provider = Provider.of<RegistrationProvider>(context, listen: false);
    provider.submitRegistration(
      context,
      formKey,
      provider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RegistrationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Registration', style: TextStyle(fontFamily: "UberMove"),),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${provider.currentStep + 1}/4',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 4,
            color: Colors.grey[200],
            child: LinearProgressIndicator(
              value: (provider.currentStep + 1) / 4,
              backgroundColor: Colors.transparent,
              color: Colors.green,
              minHeight: 4,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (index) {
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index <= provider.currentStep
                            ? (index == provider.currentStep
                                  ? Colors.green
                                  : Colors.black)
                            : Colors.grey[300],
                        border: Border.all(
                          color: index == provider.currentStep
                              ? Colors.green
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index <= provider.currentStep
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      stepTitles[index],
                      style: TextStyle(
                        color: index == provider.currentStep
                            ? Colors.black
                            : Colors.grey[600],
                        fontWeight: index == provider.currentStep
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: "UberMove",
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: provider.pageController,
              onPageChanged: (index) {
                provider.setCurrentStep(index);
              },
              children: [
                BasicInfoScreen(formKey: _formKeys[0]),
                CNICDetailsScreen(formKey: _formKeys[1]),
                DriverLicenseScreen(formKey: _formKeys[2]),
                VehicleInfoScreen(formKey: _formKeys[3]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (provider.currentStep > 0)
              OutlinedButton(
                onPressed: () {
                  provider.previousStep();
                },
                child: Text('Previous', style: TextStyle(fontFamily: "UberMove"),),
              )
            else
              SizedBox(width: 80),
            if (provider.currentStep < 3)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  alignment: Alignment.center,
                ),
                onPressed: () {
                  if (_formKeys[provider.currentStep].currentState!
                      .validate()) {
                    _formKeys[provider.currentStep].currentState!.save();
                    provider.nextStep();
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  // mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next', style: TextStyle(color: Colors.white, fontFamily: "UberMove")),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18, color: Colors.white,),
                  ],
                ),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  alignment: Alignment.center,
                ),
                onPressed: () {
                  if (_formKeys[provider.currentStep].currentState!
                      .validate()) {
                    _formKeys[provider.currentStep].currentState!.save();
                    _submitRegistration(
                      context,
                      _formKeys[provider.currentStep],
                    );
                  }
                },
                child: Text(
                  'Submit Registration',
                  style: TextStyle(color: Colors.white, fontFamily: "UberMove"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
