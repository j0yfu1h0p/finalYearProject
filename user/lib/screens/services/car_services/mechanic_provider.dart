import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:user/screens/services/car_services/service_request_confirmation_screen.dart';
import 'package:user/screens/services/car_services/waiting_for_mechanic_screen.dart';
import 'dart:convert';

import '../../../services/auth_service.dart';
import 'car_service.dart';

class MechanicProvider with ChangeNotifier {
  String? _currentLocationAddress;
  LatLng? _currentLocationCoords;
  String? _selectedService;
  bool _isLoading = false;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  LatLng _mapCenter = const LatLng(30.3753, 69.3451);
  double _mapZoom = 13.0;
  String _notes = '';
  double? _calculatedPrice;
  bool _showConfirmation = false;
  String? _serviceTypeForCalculation;
  String? _authToken;
  bool _locationServiceEnabled = false;
  bool _requestCreated = false;
  String? _requestId;
  bool _requestAccepted = false;
  Map<String, dynamic>? _mechanicDetails;
  double? _storedPrice;

  String? get currentLocationAddress => _currentLocationAddress;
  LatLng? get currentLocationCoords => _currentLocationCoords;
  String? get selectedService => _selectedService;
  bool get isLoading => _isLoading;
  bool get permissionGranted => _permissionGranted;
  bool get permissionDenied => _permissionDenied;
  bool get showPermissionBanner => _permissionDenied;
  LatLng get mapCenter => _mapCenter;
  double get mapZoom => _mapZoom;
  String get notes => _notes;
  double? get calculatedPrice => _calculatedPrice;
  bool get showConfirmation => _showConfirmation;
  String? get serviceTypeForCalculation => _serviceTypeForCalculation;
  String? get authToken => _authToken;
  bool get locationServiceEnabled => _locationServiceEnabled;
  bool get requestCreated => _requestCreated;
  String? get requestId => _requestId;
  bool get requestAccepted => _requestAccepted;
  Map<String, dynamic>? get mechanicDetails => _mechanicDetails;

  bool get hasValidServiceSelected {
    if (_selectedService == null) return false;

    for (int i = 0; i < 5; i++) {
      if (SERVICES[i]['name'] == _selectedService) return true;
    }

    return false;
  }

  bool get canRequestService {
    return hasValidServiceSelected &&
        _locationServiceEnabled &&
        _currentLocationCoords != null;
  }

  void setSelectedService(String service) {
    _selectedService = service;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setPermissionStatus(bool granted, bool denied) {
    _permissionGranted = granted;
    _permissionDenied = denied;
    notifyListeners();
  }

  void setLocationServiceStatus(bool enabled) {
    _locationServiceEnabled = enabled;
    notifyListeners();
  }

  void setCurrentLocationAddress(String address) {
    _currentLocationAddress = address;
    notifyListeners();
  }

  void updateCurrentLocation(LatLng coords) {
    _currentLocationCoords = coords;
    notifyListeners();
  }

  void updateMapPosition(LatLng center, double zoom) {
    _mapCenter = center;
    _mapZoom = zoom;
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }

  void setCalculatedPrice(double price) {
    _calculatedPrice = price;
    notifyListeners();
  }

  void setShowConfirmation(bool show) {
    _showConfirmation = show;
    notifyListeners();
  }

  void setServiceTypeForCalculation(String serviceType) {
    _serviceTypeForCalculation = serviceType;
    notifyListeners();
  }

  void setAuthToken(String token) {
    _authToken = token;
    notifyListeners();
  }

  void setRequestCreated(bool created, {String? requestId, double? price}) {
    _requestCreated = created;
    _requestId = requestId;
    _storedPrice = price;
    notifyListeners();
  }

  double? get storedPrice => _storedPrice;

  void setRequestAccepted(bool accepted, {Map<String, dynamic>? mechanicDetails}) {
    _requestAccepted = accepted;
    _mechanicDetails = mechanicDetails;
    notifyListeners();
  }

  void resetCalculation() {
    _calculatedPrice = null;
    _showConfirmation = false;
    _serviceTypeForCalculation = null;
    notifyListeners();
  }

  void resetRequest() {
    _requestCreated = false;
    _requestId = null;
    _requestAccepted = false;
    _mechanicDetails = null;
    notifyListeners();
  }
}

class ApiService {
  static const String baseUrl = 'https://smiling-sparrow-proper.ngrok-free.app';

  static Future<Map<String, dynamic>> calculatePrice(String serviceType, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/trip/rates/calculate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'serviceType': serviceType}),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format from server');
      }
      return responseData;
    } else {
      throw Exception('Price calculation failed with status: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createServiceRequest(
      String serviceType,
      List<double> coordinates,
      String notes,
      double price,
      String token,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/mechanic/requests/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'serviceType': serviceType,
        'userLocation': {'type': 'Point', 'coordinates': coordinates},
        'notes': notes,
        'priceQuote': {'amount': price, 'currency': 'PKR'},
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Service request failed with status: ${response.statusCode}');
    }
  }
}

class MechanicServicesScreen extends StatefulWidget {
  const MechanicServicesScreen({super.key});

  @override
  State<MechanicServicesScreen> createState() => _MechanicServicesScreenState();
}

class _MechanicServicesScreenState extends State<MechanicServicesScreen> {
  String? _authToken;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final token = await Auth.getToken();
      setState(() {
        _authToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      );
    }

    if (_authToken == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: screenWidth * 0.15,
                  color: Colors.red,
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Authentication Required',
                  style: TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Please authenticate to access mechanic services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                ElevatedButton(
                  onPressed: _loadToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                      vertical: screenHeight * 0.015,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Retry Authentication',
                    style: TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: screenWidth * 0.035,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (context) => MechanicProvider()..setAuthToken(_authToken!),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(color: Colors.black),
        ),
        body: Consumer<MechanicProvider>(
          builder: (context, provider, child) {
            if (provider.requestAccepted &&
                provider.mechanicDetails != null &&
                provider.selectedService != null &&
                provider.calculatedPrice != null &&
                provider.currentLocationAddress != null) {
              return MechanicAssignedScreen(
                mechanicDetails: provider.mechanicDetails!,
                serviceType: provider.selectedService!,
                price: provider.calculatedPrice!,
                location: provider.currentLocationAddress!,
                notes: provider.notes,
              );
            } else if (provider.requestCreated &&
                provider.requestId != null &&
                provider.selectedService != null) {
              return WaitingForMechanicScreen(
                requestId: provider.requestId!,
                serviceType: provider.selectedService!,
                onCancel: () {
                  provider.resetRequest();
                  provider.resetCalculation();
                },
              );
            } else if (provider.showConfirmation) {
              return ServiceRequestConfirmationScreen(
                onBack: () {
                  provider.resetCalculation();
                },
                onCreateRequest: () async {
                  try {
                    provider.setLoading(true);

                    if (provider.currentLocationCoords == null ||
                        provider.serviceTypeForCalculation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Location or service type not available'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      provider.setLoading(false);
                      return;
                    }

                    final price = provider.calculatedPrice ?? 0.0;

                    final response = await ApiService.createServiceRequest(
                      provider.serviceTypeForCalculation!,
                      [
                        provider.currentLocationCoords!.longitude,
                        provider.currentLocationCoords!.latitude,
                      ],
                      provider.notes,
                      price,
                      provider.authToken ?? '',
                    );

                    final requestId = response['_id'] ?? 'req_${DateTime.now().millisecondsSinceEpoch}';

                    provider.setRequestCreated(true, requestId: requestId, price: price);
                    provider.resetCalculation();

                    Future.delayed(const Duration(seconds: 10), () {
                      if (provider.requestCreated && mounted) {
                        provider.setRequestAccepted(
                          true,
                          mechanicDetails: {
                            'name': 'John Doe',
                            'rating': 4.8,
                            'reviews': 127,
                            'eta': '15 min',
                            'vehicle': 'Toyota Corolla',
                            'plateNumber': 'ABC-123',
                            'phone': '+1234567890',
                          },
                        );
                      }
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating service request: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      provider.setLoading(false);
                    }
                  }
                },
              );
            } else {
              return SafeArea(
                child: Column(
                  children: [
                    Flexible(
                      flex: screenHeight > 600 ? 2 : 3,
                      child: const MapSection(),
                    ),
                    Flexible(
                      flex: screenHeight > 600 ? 4 : 5,
                      child: const ServicesSelectionSection(),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class MapSection extends StatefulWidget {
  const MapSection({super.key});

  @override
  State<MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<MapSection> {
  final MapController _mapController = MapController();
  static const LatLng _pakistanCenter = LatLng(30.3753, 69.3451);

  final TileLayer _tileLayer = TileLayer(
    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    userAgentPackageName: 'com.example.myautobridge',
  );

  void _showPermissionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'UberMove')),
        content: Text(content, style: const TextStyle(fontFamily: 'UberMove')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(fontFamily: 'UberMove')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_pakistanCenter, 18.0);
      Provider.of<MechanicProvider>(context, listen: false).updateMapPosition(_pakistanCenter, 18.0);
    });
    _checkLocationServices();
    _checkLocationPermission();
  }

  Future<void> _checkLocationServices() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    Provider.of<MechanicProvider>(context, listen: false).setLocationServiceStatus(serviceEnabled);

    if (!serviceEnabled && mounted) {
      _showPermissionDialog(
        "Location Services Disabled",
        "Your location services are turned off. Please enable them in your device settings to request a mechanic.",
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    final provider = Provider.of<MechanicProvider>(context, listen: false);
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.whileInUse || permission == LocationPermission.always;

      provider.setPermissionStatus(granted, !granted);

      if (!granted && mounted) {
        _showPermissionDialog(
          "Location Permission Required",
          "We need location permission to find mechanics near your current location. Please grant access in settings to continue.",
        );
        return;
      }
    } else {
      provider.setPermissionStatus(true, false);
    }

    if (provider.permissionGranted && mounted) {
      await _getCurrentPosition();
    }
  }

  Future<void> _getCurrentPosition() async {
    final provider = Provider.of<MechanicProvider>(context, listen: false);
    if (!provider.permissionGranted || !mounted) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    provider.setLocationServiceStatus(serviceEnabled);

    if (!serviceEnabled && mounted) {
      _showPermissionDialog(
        "Location Services Disabled",
        "Your location services are turned off. Please enable them in your device settings to request a mechanic.",
      );
      return;
    }

    try {
      provider.setLoading(true);
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final current = LatLng(position.latitude, position.longitude);

      _mapController.move(current, provider.mapZoom);
      provider.updateCurrentLocation(current);

      final coordsText = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      provider.setCurrentLocationAddress(coordsText);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) provider.setLoading(false);
    }
  }

  void _navigateBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final provider = Provider.of<MechanicProvider>(context);

    return Container(
      color: Colors.grey[200],
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pakistanCenter,
              initialZoom: provider.mapZoom,
              onPositionChanged: (camera, _) {
                provider.updateMapPosition(camera.center, camera.zoom);
              },
            ),
            children: [
              _tileLayer,
              if (provider.permissionGranted && provider.currentLocationCoords != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: provider.currentLocationCoords!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: screenWidth * 0.09,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            top: provider.showPermissionBanner ? screenHeight * 0.08 : screenHeight * 0.02,
            left: screenWidth * 0.04,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _navigateBack,
              child: Icon(Icons.arrow_back, color: Colors.black, size: screenWidth * 0.06),
            ),
          ),

          Positioned(
            top: provider.showPermissionBanner ? screenHeight * 0.08 : screenHeight * 0.02,
            right: screenWidth * 0.04,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _checkLocationServices();
                _getCurrentPosition();
              },
              child: Icon(Icons.my_location, color: Colors.black, size: screenWidth * 0.06),
            ),
          ),

          if (!provider.locationServiceEnabled)
            Positioned(
              bottom: screenHeight * 0.02,
              left: screenWidth * 0.04,
              right: screenWidth * 0.04,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Location services are disabled. Please enable them to request a mechanic.',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'UberMove',
                    fontSize: screenWidth * 0.035,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (provider.isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class ServicesSelectionSection extends StatefulWidget {
  const ServicesSelectionSection({super.key});

  @override
  State<ServicesSelectionSection> createState() => _ServicesSelectionSectionState();
}

class _ServicesSelectionSectionState extends State<ServicesSelectionSection> {
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _notesFocusNode = FocusNode();
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<MechanicProvider>(context, listen: false);
    _notesController.text = provider.notes;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
      _notesFocusNode.addListener(() {
        if (mounted) setState(() {
          _keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        });
      });
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _calculatePrice() async {
    final provider = Provider.of<MechanicProvider>(context, listen: false);

    if (!provider.canRequestService) {
      if (!provider.locationServiceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enable location services to request a mechanic'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!provider.hasValidServiceSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a service from the first 5 options'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (provider.currentLocationCoords == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait while we get your location'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }
    }

    try {
      provider.setLoading(true);

      String serviceType = '';
      for (var service in SERVICES) {
        if (service['name'] == provider.selectedService) {
          serviceType = service['type'] as String;
          break;
        }
      }

      final response = await ApiService.calculatePrice(serviceType, provider.authToken ?? '');
      final totalPrice = response['totalPrice'];

      if (totalPrice != null) {
        provider.setCalculatedPrice(totalPrice.toDouble());
      } else {
        throw Exception('Price calculation failed: No totalPrice in response');
      }

      provider.setServiceTypeForCalculation(serviceType);
      provider.setShowConfirmation(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating price: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) provider.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final provider = Provider.of<MechanicProvider>(context);

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: screenWidth * 0.06),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: provider.isLoading
                    ? Text(
                  'Getting your location...',
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'UberMove',
                    fontSize: screenWidth * 0.035,
                  ),
                )
                    : Text(
                  provider.currentLocationAddress ?? 'Location not available',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.035,
                    fontFamily: 'UberMove',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),

          Text(
            'Select Service Needed',
            style: TextStyle(
              color: Colors.black,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              fontFamily: 'UberMove',
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          if (provider.selectedService == 'Add Notes')
            Column(
              children: [
                TextField(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Add any special instructions or details...',
                    hintStyle: TextStyle(fontFamily: 'UberMove', fontSize: screenWidth * 0.035),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
                  ),
                  maxLines: 2,
                  onChanged: (value) => provider.setNotes(value),
                ),
                SizedBox(height: screenHeight * 0.02),
              ],
            ),

          Expanded(
            flex: _keyboardVisible ? 1 : 3,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: screenWidth > 600 ? 4 : 3,
                crossAxisSpacing: screenWidth * 0.02,
                mainAxisSpacing: screenWidth * 0.02,
                childAspectRatio: 0.8,
              ),
              itemCount: SERVICES.length,
              itemBuilder: (context, index) {
                final service = SERVICES[index];
                final isSelected = provider.selectedService == service['name'];
                final isNotesCard = service['name'] == 'Add Notes';
                final hasNotes = provider.notes.isNotEmpty;

                return Card(
                  color: isSelected ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? Colors.black : Colors.grey.shade300, width: 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      provider.setSelectedService(service['name'] as String);
                      if (isNotesCard) {
                        FocusScope.of(context).requestFocus(_notesFocusNode);
                      } else {
                        _notesFocusNode.unfocus();
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.03),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            service['icon'] as IconData,
                            color: isSelected ? Colors.green : Colors.black,
                            size: screenWidth * 0.06,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          if (isNotesCard && hasNotes)
                            Expanded(
                              child: Text(
                                provider.notes,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontSize: screenWidth * 0.028,
                                  fontFamily: 'UberMove',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            Text(
                              service['name'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.03,
                                fontFamily: 'UberMove',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (!_keyboardVisible) SizedBox(height: screenHeight * 0.02),

          if (!_keyboardVisible)
            SizedBox(
              width: screenWidth,
              height: screenHeight * 0.07,
              child: ElevatedButton(
                onPressed: _calculatePrice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.canRequestService ? Colors.green : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: Text(
                  provider.canRequestService ? 'Request Mechanic' : 'Enable Location',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.04,
                    fontFamily: 'UberMove',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          if (!_keyboardVisible) SizedBox(height: screenHeight * 0.01),
        ],
      ),
    );
  }
}