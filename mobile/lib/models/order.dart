import 'package:flutter/material.dart';

import '../core/format.dart';

class OrderPerson {
  const OrderPerson({required this.id, required this.fullName, this.phone});

  final int id;
  final String fullName;
  final String? phone;

  factory OrderPerson.fromJson(Map<String, dynamic> json) {
    return OrderPerson(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? 'Utilisateur',
      phone: (json['phone'] as String?)?.trim(),
    );
  }
}

class OrderRestaurant {
  const OrderRestaurant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.address,
  });

  final int id;
  final String name;
  final String emoji;
  final String color;
  final String address;

  Color get tint => colorFromHex(color);

  factory OrderRestaurant.fromJson(Map<String, dynamic> json) {
    return OrderRestaurant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Restaurant',
      emoji: json['emoji'] as String? ?? '🍽️',
      color: json['color'] as String? ?? '#FF6B35',
      address: json['address'] as String? ?? '',
    );
  }
}

class OrderLine {
  const OrderLine({
    required this.id,
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.emoji,
  });

  final int id;
  final int? productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String emoji;

  double get total => unitPrice * quantity;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      emoji: json['emoji'] as String? ?? '🍽️',
    );
  }
}

class FoodOrder {
  const FoodOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.address,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.restaurant,
    required this.client,
    required this.items,
    this.courier,
  });

  final int id;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String address;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderRestaurant restaurant;
  final OrderPerson client;
  final OrderPerson? courier;
  final List<OrderLine> items;

  bool get isActive => isActiveOrder(status);
  bool get canCancel => canCancelOrder(status);
  int get itemCount => items.fold(0, (sum, line) => sum + line.quantity);

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return FoodOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: parseApiDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseApiDate(json['updated_at']) ?? DateTime.now(),
      restaurant: OrderRestaurant.fromJson(
        (json['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      client: OrderPerson.fromJson(
        (json['client'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      courier: json['courier'] == null
          ? null
          : OrderPerson.fromJson(
              (json['courier'] as Map).cast<String, dynamic>(),
            ),
      items: rawItems
          .map(
            (item) => OrderLine.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
