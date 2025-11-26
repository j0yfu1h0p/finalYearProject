import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:user/screens/services/review_route_screen.dart';

import '../../providers/map_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_util.dart';
import '../../utils/error_handler.dart';

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'MyAutoBridge/1.0 (TowingServicesApp)',
  };

  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        '$_baseUrl/search?q=$encoded&format=json&countrycodes=pk',
      );
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String> reverse(LatLng point) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'MyAutoBridge/1.0 (TowingServicesApp)',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final List<String> addressParts = [];

          if (address['road'] != null) addressParts.add(address['road']);
          if (address['suburb'] != null) addressParts.add(address['suburb']);
          if (address['city'] != null) addressParts.add(address['city']);
          if (address['state'] != null) addressParts.add(address['state']);
          if (address['country'] != null) addressParts.add(address['country']);

          return addressParts.isNotEmpty
              ? addressParts.join(', ')
              : data['display_name'] ?? 'Unknown Location';
        }

        return data['display_name'] ?? 'Unknown Location';
      } else {
        return 'Unknown Location';
      }
    } catch (e) {
      return 'Unknown Location';
    }
  }



  Future<LatLng?> forward(String address) async {
    try {
      if (address.trim().isEmpty) return null;
      final encoded = Uri.encodeComponent(address);
      final url = Uri.parse(
        '$_baseUrl/search?q=$encoded&format=json&countrycodes=pk&limit=1',
      );
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        if (list.isNotEmpty) {
          final first = list[0];
          return LatLng(double.parse(first['lat']), double.parse(first['lon']));
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class RouteService {
  static const String _base = 'https://router.project-osrm.org/route/v1/driving';

  Future<(double distance, double duration, List<LatLng> points)?> route(
      LatLng start,
      LatLng end,
      ) async {
    final url = Uri.parse(
      '$_base/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body);
      final routes = (body['routes'] as List?);
      if (routes == null || routes.isEmpty) return null;
      final route = routes[0];
      final geometry = route['geometry'];
      if (geometry == null || geometry['type'] != 'LineString') return null;
      final coords = (geometry['coordinates'] as List)
          .map<LatLng>((pt) => LatLng(pt[1].toDouble(), pt[0].toDouble()))
          .toList(growable: false);
      final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (route['duration'] as num?)?.toDouble() ?? 0.0;
      return (distance, duration, coords);
    } catch (e) {
      return null;
    }
  }
}

class VehicleSelectionScreen extends StatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: Container(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 2, child: MapSection()),
            Expanded(flex: 3, child: VehicleSelectionSection()),
          ],
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
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
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
      Provider.of<MapProvider>(context, listen: false)
          .updateMapPosition(_pakistanCenter, 18.0);
    });
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final provider = Provider.of<MapProvider>(context, listen: false);
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      provider.setPermissionStatus(granted, !granted);

      if (!granted) {
        _showPermissionDialog(
          "Location Permission Required",
          "We need location permission to show your current location on the map.",
        );
        return;
      }
    } else {
      provider.setPermissionStatus(true, false);
    }

    if (provider.permissionGranted) {
      await _getCurrentPosition();
    }
  }

  Future<void> _getCurrentPosition() async {
    final provider = Provider.of<MapProvider>(context, listen: false);
    if (!provider.permissionGranted) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showPermissionDialog(
        "Location Services Disabled",
        "Your location services are turned off.",
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      final current = LatLng(position.latitude, position.longitude);

      _mapController.move(current, provider.mapZoom);
      provider.updateCurrentLocation(current);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtil.showError(context, ErrorHandler.sanitizeErrorMessage(e));
    }
  }

  Future<void> _setDestinationFromMap() async {
    final provider = Provider.of<MapProvider>(context, listen: false);
    provider.setSettingDestination(false);
    await provider.updateDestinationFromCoords(provider.mapCenter);
  }

  void _startSetDestinationMode() {
    final provider = Provider.of<MapProvider>(context, listen: false);
    provider.setSettingDestination(true);
    provider.clearRoute();
    SnackBarUtil.showInfo(context, 'Move the map to set your destination');
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final provider = Provider.of<MapProvider>(context);

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
              if (provider.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: provider.routePoints,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              if (provider.permissionGranted &&
                  provider.currentLocationCoords != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: provider.currentLocationCoords!,
                      width: screenWidth * 0.1,
                      height: screenWidth * 0.1,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: screenWidth * 0.1,
                      ),
                    ),
                  ],
                ),
              if (provider.destinationLocationCoords != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: provider.destinationLocationCoords!,
                      width: screenWidth * 0.1,
                      height: screenWidth * 0.1,
                      child: Icon(
                        Icons.pin_drop,
                        color: Colors.blue,
                        size: screenWidth * 0.1,
                      ),
                    ),
                  ],
                ),
              if (provider.settingDestination)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: provider.mapCenter,
                      width: screenWidth * 0.1,
                      height: screenWidth * 0.1,
                      child: Icon(
                        Icons.pin_drop,
                        color: Colors.grey,
                        size: screenWidth * 0.1,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            top: provider.showPermissionBanner ? 100 : 50,
            left: screenWidth * 0.05,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _goBack,
              child: Icon(Icons.arrow_back, color: Colors.black, size: screenWidth * 0.06),
            ),
          ),

          Positioned(
            top: provider.showPermissionBanner ? 100 : 50,
            right: screenWidth * 0.05,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _getCurrentPosition,
                  child: Icon(Icons.my_location, color: Colors.black, size: screenWidth * 0.06),
                ),
                SizedBox(height: screenWidth * 0.03),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: provider.settingDestination
                      ? Colors.green
                      : Colors.white,
                  onPressed: provider.settingDestination
                      ? _setDestinationFromMap
                      : _startSetDestinationMode,
                  child: Icon(
                    provider.settingDestination ? Icons.check : Icons.flag,
                    color: Colors.black,
                    size: screenWidth * 0.06,
                  ),
                ),
              ],
            ),
          ),

          if (provider.isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class VehicleSelectionSection extends StatefulWidget {
  const VehicleSelectionSection({super.key});

  @override
  State<VehicleSelectionSection> createState() =>
      _VehicleSelectionSectionState();
}

class _VehicleSelectionSectionState extends State<VehicleSelectionSection> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _destinationFocus.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _destinationFocus.removeListener(_handleFocusChange);
    _destinationFocus.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_destinationFocus.hasFocus && _destinationController.text.isNotEmpty) {
      _handleDestinationInput(_destinationController.text);
    }
  }

  Future<void> _handleDestinationInput(String address) async {
    final provider = Provider.of<MapProvider>(context, listen: false);
    await provider.updateDestination(address);
    if (provider.destinationLocationCoords == null && mounted) {
      SnackBarUtil.showError(context, 'Could not find location');
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Calculating...';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return 'Calculating...';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '${hours}h ${remaining}min';
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.black,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    if (mapProvider.currentLocationAddress != null &&
        _pickupController.text != mapProvider.currentLocationAddress) {
      _pickupController.text = mapProvider.currentLocationAddress!;
    }
    if (mapProvider.destinationLocationAddress != null &&
        _destinationController.text != mapProvider.destinationLocationAddress) {
      _destinationController.text = mapProvider.destinationLocationAddress!;
    }

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            'Select your Vehicle',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              fontFamily: 'UberMove',
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              VehicleOption(
                imageAsset: 'assets/images/two_wheeler.png',
                selectedImageAsset: 'assets/images/two_wheeler_selected.png',
                label: 'Two Wheeler',
                isSelected: mapProvider.selectedVehicle == 'Two Wheeler',
                onSelect: () => mapProvider.setSelectedVehicle('Two Wheeler'),
                screenHeight: screenHeight,
              ),
              VehicleOption(
                imageAsset: 'assets/images/four_wheeler.png',
                selectedImageAsset: 'assets/images/four_wheeler_selected.png',
                label: 'Four Wheeler',
                isSelected: mapProvider.selectedVehicle == 'Four Wheeler',
                onSelect: () => mapProvider.setSelectedVehicle('Four Wheeler'),
                screenHeight: screenHeight,
              ),
              VehicleOption(
                imageAsset: 'assets/images/heavy_vehicle.png',
                selectedImageAsset: 'assets/images/heavy_vehicle_selected.png',
                label: 'Heavy Vehicle',
                isSelected: mapProvider.selectedVehicle == 'Heavy Vehicle',
                onSelect: () => mapProvider.setSelectedVehicle('Heavy Vehicle'),
                screenHeight: screenHeight,
              ),
            ],
          ),

          SizedBox(height: screenHeight * 0.01),
          Container(
            height: 1,
            color: Colors.grey[600],
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
          ),
          SizedBox(height: screenHeight * 0.03),

          TextField(
            controller: _pickupController,
            readOnly: true,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'UberMove',
              fontSize: screenWidth * 0.04,
            ),
            decoration: _inputDecoration('Pickup Point'),
          ),

          SizedBox(height: screenHeight * 0.015),

          TypeAheadField<Map<String, dynamic>>(
            controller: _destinationController,
            focusNode: _destinationFocus,
            debounceDuration: const Duration(milliseconds: 350),
            suggestionsCallback: (pattern) async {
              if (pattern.isEmpty) return [];
              return await NominatimService().search(pattern);
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                title: Text(
                  suggestion['display_name'] ?? 'Unknown',
                  style: TextStyle(fontSize: screenWidth * 0.035),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
            onSelected: (suggestion) {
              final address = suggestion['display_name'] as String? ?? '';
              _destinationController.text = address;
              _handleDestinationInput(address);
            },
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'UberMove',
                  fontSize: screenWidth * 0.04,
                ),
                decoration: _inputDecoration('Where to go'),
                onSubmitted: _handleDestinationInput,
              );
            },
            emptyBuilder: (context) => Padding(
              padding: EdgeInsets.all(screenWidth * 0.03),
              child: Text(
                'No results',
                style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.035),
              ),
            ),
            loadingBuilder: (context) => Padding(
              padding: EdgeInsets.all(screenWidth * 0.03),
              child: const CircularProgressIndicator(),
            ),
          ),

          Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              if (mapProvider.isLoading) {
                return Padding(
                  padding: EdgeInsets.all(screenWidth * 0.01),
                  child: const CircularProgressIndicator(color: Colors.white),
                );
              }
              if (mapProvider.routeDistance != null &&
                  mapProvider.routeDuration != null) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: Colors.white, size: screenWidth * 0.05),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            _formatDistance(mapProvider.routeDistance),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.035,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.white, size: screenWidth * 0.05),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            _formatDuration(mapProvider.routeDuration),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.035,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),

          SizedBox(height: screenHeight * 0.01),

          SizedBox(
            width: screenWidth,
            height: screenHeight * 0.08,
            child: ElevatedButton(
              onPressed: () {
                if (mapProvider.selectedVehicle == null) {
                  SnackBarUtil.showWarning(context, 'Please select a vehicle type');
                  return;
                }
                if (mapProvider.destinationLocationCoords == null) {
                  SnackBarUtil.showWarning(context, 'Please set a destination');
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReviewRouteScreen(
                      selectedVehicle: mapProvider.selectedVehicle!,
                      pickupLocation: _pickupController.text,
                      destinationLocation: _destinationController.text,
                      distance: mapProvider.routeDistance,
                      duration: mapProvider.routeDuration,
                      pickupLatitude: mapProvider.currentLocationCoords?.latitude,
                      pickupLongitude: mapProvider.currentLocationCoords?.longitude,
                      destinationLatitude: mapProvider.destinationLocationCoords?.latitude,
                      destinationLongitude: mapProvider.destinationLocationCoords?.longitude,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Find',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: screenWidth * 0.045,
                  fontFamily: 'UberMove',
                ),
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }
}

class VehicleOption extends StatelessWidget {
  final String imageAsset;
  final String selectedImageAsset;
  final String label;
  final bool isSelected;
  final VoidCallback onSelect;
  final double screenHeight;

  const VehicleOption({
    super.key,
    required this.imageAsset,
    required this.selectedImageAsset,
    required this.label,
    required this.isSelected,
    required this.onSelect,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Column(
        children: [
          Container(
            width: screenHeight * 0.10,
            height: screenHeight * 0.10,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              isSelected ? selectedImageAsset : imageAsset,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF89D29F) : Colors.grey,
              fontSize: screenHeight * 0.015,
            ),
          ),
        ],
      ),
    );
  }
}