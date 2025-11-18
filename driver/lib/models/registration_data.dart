// Registration data model to hold user information
import 'dart:io';

class RegistrationData {
  String? firstName;
  String? lastName;
  DateTime? dateOfBirth;
  String? email;
  File? profilePhoto;
  String? profilePhotoUrl;

  String? cnicNumber;
  File? cnicFront;
  File? cnicBack;
  String? cnicFrontUrl;
  String? cnicBackUrl;

  String? licenseNumber;
  File? licensePhoto;
  DateTime? licenseExpiryDate;
  String? licensePhotoUrl;

  String? vehicleType;
  String? companyModel;
  String? vehicleColor;
  String? numberPlate;
  String? manufacturingYear;
  File? vehiclePhoto;
  File? registrationFront;
  File? registrationBack;
  String? vehiclePhotoUrl;
  String? registrationFrontUrl;
  String? registrationBackUrl;

  bool get isMechanic => false;

  // Helper method to get URL fields
  String? getUrlField(String fieldName) {
    switch (fieldName) {
      case 'profilePhotoUrl': return profilePhotoUrl;
      case 'cnicFrontUrl': return cnicFrontUrl;
      case 'cnicBackUrl': return cnicBackUrl;
      case 'licensePhotoUrl': return licensePhotoUrl;
      case 'vehiclePhotoUrl': return vehiclePhotoUrl;
      case 'registrationFrontUrl': return registrationFrontUrl;
      case 'registrationBackUrl': return registrationBackUrl;
      default: return null;
    }
  }

  // Helper method to set URL fields
  void setUrlField(String fieldName, String url) {
    switch (fieldName) {
      case 'profilePhotoUrl': profilePhotoUrl = url; break;
      case 'cnicFrontUrl': cnicFrontUrl = url; break;
      case 'cnicBackUrl': cnicBackUrl = url; break;
      case 'licensePhotoUrl': licensePhotoUrl = url; break;
      case 'vehiclePhotoUrl': vehiclePhotoUrl = url; break;
      case 'registrationFrontUrl': registrationFrontUrl = url; break;
      case 'registrationBackUrl': registrationBackUrl = url; break;
    }
  }

  // Check if all images are uploaded
  bool areAllImagesUploaded() {
    return profilePhotoUrl != null &&
        cnicFrontUrl != null &&
        cnicBackUrl != null &&
        licensePhotoUrl != null &&
        vehiclePhotoUrl != null &&
        registrationFrontUrl != null &&
        registrationBackUrl != null;
  }

  // List missing image URLs
  List<String> getMissingImageUrls() {
    List<String> missing = [];
    if (profilePhotoUrl == null) missing.add('Profile Photo');
    if (cnicFrontUrl == null) missing.add('CNIC Front');
    if (cnicBackUrl == null) missing.add('CNIC Back');
    if (licensePhotoUrl == null) missing.add('License Photo');
    if (vehiclePhotoUrl == null) missing.add('Vehicle Photo');
    if (registrationFrontUrl == null) missing.add('Registration Front');
    if (registrationBackUrl == null) missing.add('Registration Back');
    return missing;
  }

  // List missing local image files (before upload)
  List<String> getMissingImageFiles() {
    List<String> missing = [];
    if (profilePhoto == null) missing.add('Profile Photo');
    if (cnicFront == null) missing.add('CNIC Front');
    if (cnicBack == null) missing.add('CNIC Back');
    if (licensePhoto == null) missing.add('License Photo');
    if (vehiclePhoto == null) missing.add('Vehicle Photo');
    if (registrationFront == null) missing.add('Registration Front');
    if (registrationBack == null) missing.add('Registration Back');
    return missing;
  }

  // Check if all required fields are filled
  bool areAllRequiredFieldsFilled() {
    return firstName != null && firstName!.isNotEmpty &&
        lastName != null && lastName!.isNotEmpty &&
        dateOfBirth != null &&
        cnicNumber != null && cnicNumber!.isNotEmpty &&
        licenseNumber != null && licenseNumber!.isNotEmpty &&
        licenseExpiryDate != null &&
        vehicleType != null && vehicleType!.isNotEmpty &&
        companyModel != null && companyModel!.isNotEmpty &&
        vehicleColor != null && vehicleColor!.isNotEmpty &&
        numberPlate != null && numberPlate!.isNotEmpty &&
        manufacturingYear != null && manufacturingYear!.isNotEmpty;
  }

  // List missing required fields
  List<String> getMissingRequiredFields() {
    List<String> missing = [];
    if (firstName == null || firstName!.isEmpty) missing.add('First Name');
    if (lastName == null || lastName!.isEmpty) missing.add('Last Name');
    if (dateOfBirth == null) missing.add('Date of Birth');
    if (cnicNumber == null || cnicNumber!.isEmpty) missing.add('CNIC Number');
    if (licenseNumber == null || licenseNumber!.isEmpty) missing.add('License Number');
    if (licenseExpiryDate == null) missing.add('License Expiry Date');
    if (vehicleType == null || vehicleType!.isEmpty) missing.add('Vehicle Type');
    if (companyModel == null || companyModel!.isEmpty) missing.add('Company & Model');
    if (vehicleColor == null || vehicleColor!.isEmpty) missing.add('Vehicle Color');
    if (numberPlate == null || numberPlate!.isEmpty) missing.add('Number Plate');
    if (manufacturingYear == null || manufacturingYear!.isEmpty) missing.add('Manufacturing Year');
    return missing;
  }
}