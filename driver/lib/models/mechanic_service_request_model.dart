class MechanicServiceRequest {
  final String id;
  final String userId;
  final String serviceType;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final Location userLocation;
  final PriceQuote? priceQuote;

  MechanicServiceRequest({
    required this.id,
    required this.userId,
    required this.serviceType,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.userLocation,
    this.priceQuote,
  });

  factory MechanicServiceRequest.fromJson(Map<String, dynamic> json) {
    return MechanicServiceRequest(
      id: json['_id'],
      userId: json['userId'],
      serviceType: json['serviceType'],
      notes: json['notes'] ?? '',
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      userLocation: Location.fromJson(json['userLocation']),
      priceQuote: json['priceQuote'] != null
          ? PriceQuote.fromJson(json['priceQuote'])
          : null,
    );
  }
}

class Location {
  final String type;
  final List<double> coordinates;

  Location({required this.type, required this.coordinates});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      type: json['type'],
      coordinates: List<double>.from(json['coordinates'].map((x) => x.toDouble())),
    );
  }
}

// Price quote model for mechanic service requests
class PriceQuote {
  final double amount;
  final String currency;
  final DateTime updatedAt;
  final DateTime providedAt;

  PriceQuote({
    required this.amount,
    required this.currency,
    required this.updatedAt,
    required this.providedAt,
  });

  factory PriceQuote.fromJson(Map<String, dynamic> json) {
    // Handle amount conversion safely
    double amount;
    if (json['amount'] is int) {
      amount = (json['amount'] as int).toDouble();
    } else if (json['amount'] is double) {
      amount = json['amount'];
    } else if (json['amount'] is String) {
      amount = double.tryParse(json['amount']) ?? 0.0;
    } else {
      amount = 0.0;
    }

    return PriceQuote(
      amount: amount,
      currency: json['currency']?.toString() ?? 'PKR',
      updatedAt: DateTime.parse(json['updatedAt']),
      providedAt: DateTime.parse(json['providedAt']),
    );
  }
}