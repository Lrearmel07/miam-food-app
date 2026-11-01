import 'package:flutter/material.dart';

import '../core/format.dart';

class DeliveryZone {
  const DeliveryZone({required this.zone, required this.fee});

  final String zone;
  final double fee;

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      zone: json['zone'] as String? ?? '',
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    this.emoji = '',
    this.imageUrl,
    this.coverImageUrl,
    required this.color,
    required this.rating,
    this.reviewCount = 0,
    required this.deliveryFee,
    required this.minOrder,
    required this.etaMin,
    required this.address,
    required this.isOpen,
    required this.productCount,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.ownerId,
    this.openingHours,
    this.deliveryZones = const [],
    this.promoText,
    this.promoBadge,
  });

  final int id;
  final String name;
  final String description;
  final String cuisine;
  final String emoji;
  final String? imageUrl;
  final String? coverImageUrl;
  final String color;
  final double rating;
  final int reviewCount;
  final double deliveryFee;
  final double minOrder;
  final int etaMin;
  final String address;
  final bool isOpen;
  final int productCount;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final int? ownerId;
  final String? openingHours;
  final List<DeliveryZone> deliveryZones;
  final String? promoText;
  final String? promoBadge;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasPromo => promoText != null && promoText!.isNotEmpty;

  Color get tint => colorFromHex(color);

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    final zones = json['delivery_zones'];
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? 'International',
      emoji: json['emoji'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      color: json['color'] as String? ?? '#FF7A45',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      minOrder: (json['min_order'] as num?)?.toDouble() ?? 0,
      etaMin: (json['eta_min'] as num?)?.toInt() ?? 25,
      address: json['address'] as String? ?? '',
      isOpen: json['is_open'] as bool? ?? true,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      ownerId: (json['owner_id'] as num?)?.toInt(),
      openingHours: json['opening_hours'] as String?,
      deliveryZones: zones is List
          ? zones
                .whereType<Map>()
                .map((e) => DeliveryZone.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      promoText: json['promo_text'] as String?,
      promoBadge: json['promo_badge'] as String?,
    );
  }
}
