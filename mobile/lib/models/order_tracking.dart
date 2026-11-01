import '../core/format.dart';

class TrackingPlace {
  const TrackingPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;

  factory TrackingPlace.fromJson(Map<String, dynamic> json) {
    return TrackingPlace(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TrackingCourier {
  const TrackingCourier({
    required this.id,
    required this.fullName,
    this.phone,
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  final int id;
  final String fullName;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  factory TrackingCourier.fromJson(Map<String, dynamic> json) {
    return TrackingCourier(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? 'Livreur',
      phone: (json['phone'] as String?)?.trim(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: parseApiDate(json['updated_at']),
    );
  }
}

class OrderTracking {
  const OrderTracking({
    required this.orderId,
    required this.status,
    required this.restaurant,
    required this.delivery,
    required this.distanceRemainingKm,
    required this.etaMinutes,
    required this.updatedAt,
    this.courier,
  });

  final int orderId;
  final String status;
  final TrackingPlace restaurant;
  final TrackingPlace delivery;
  final TrackingCourier? courier;
  final double distanceRemainingKm;
  final int etaMinutes;
  final DateTime updatedAt;

  bool get isDelivered => status == 'delivered';
  bool get isShipping => status == 'shipping';

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    return OrderTracking(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      restaurant: TrackingPlace.fromJson(
        (json['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      delivery: TrackingPlace.fromJson(
        (json['delivery'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      courier: json['courier'] == null
          ? null
          : TrackingCourier.fromJson(
              (json['courier'] as Map).cast<String, dynamic>(),
            ),
      distanceRemainingKm:
          (json['distance_remaining_km'] as num?)?.toDouble() ?? 0,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 0,
      updatedAt: parseApiDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}
