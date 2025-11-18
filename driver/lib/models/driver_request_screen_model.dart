class ServiceRequest {
  final String id;
  final String vehicleType;
  final PickupLocation pickupLocation;
  final Destination destination;
  final String driverId;
  final double distance;
  final int duration;
  final double rate;
  final double totalAmount;
  final String status;
  final String userId;
  final DateTime createdAt;

  ServiceRequest({
    required this.id,
    required this.vehicleType,
    required this.pickupLocation,
    required this.destination,
    required this.driverId,
    required this.distance,
    required this.duration,
    required this.rate,
    required this.totalAmount,
    required this.status,
    required this.userId,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['_id'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      pickupLocation: PickupLocation.fromJson(json['pickupLocation'] ?? {}),
      destination: Destination.fromJson(json['destination'] ?? {}),
      driverId: json['driverId'] ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      userId: json['userId'] is Map ? json['userId']['_id'] ?? '' : json['userId'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class PickupLocation {
  final String address;
  final Coordinates coordinates;

  PickupLocation({
    required this.address,
    required this.coordinates,
  });

  factory PickupLocation.fromJson(Map<String, dynamic> json) {
    // Handle both backend formats - the new format with 'location' and old format
    if (json['location'] != null && json['location'] is Map) {
      // New format: pickupLocation.location.coordinates
      final location = json['location'];
      if (location['coordinates'] is List && (location['coordinates'] as List).length == 2) {
        final coords = location['coordinates'] as List;
        return PickupLocation(
          address: json['address'] ?? '',
          coordinates: Coordinates(
            lat: (coords[1] as num).toDouble(), // latitude is 2nd element
            lng: (coords[0] as num).toDouble(), // longitude is 1st element
          ),
        );
      }
    }

    // Old format or fallback: pickupLocation.coordinates
    return PickupLocation(
      address: json['address'] ?? '',
      coordinates: Coordinates.fromJson(json['coordinates'] ?? {}),
    );
  }
}

class Destination {
  final String address;
  final Coordinates coordinates;

  Destination({
    required this.address,
    required this.coordinates,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      address: json['address'] ?? '',
      coordinates: Coordinates.fromJson(json['coordinates'] ?? {}),
    );
  }
}

class Coordinates {
  final double lat;
  final double lng;

  Coordinates({
    required this.lat,
    required this.lng,
  });

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }
}