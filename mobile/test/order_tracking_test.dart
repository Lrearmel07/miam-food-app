import 'package:flutter_test/flutter_test.dart';
import 'package:miam/core/format.dart';
import 'package:miam/models/order_tracking.dart';

void main() {
  test('les dates API sans fuseau sont interprétées en UTC', () {
    final date = parseApiDate('2026-10-26T12:00:00');
    expect(date?.isUtc, isTrue);
    expect(parseApiDate('2026-10-26T12:00:00Z')?.isUtc, isTrue);
  });

  test('le suivi de commande est désérialisé avec la position du livreur', () {
    final tracking = OrderTracking.fromJson({
      'order_id': 42,
      'status': 'shipping',
      'restaurant': {
        'name': 'Chez Mama',
        'address': 'Rue L88, Cocody Angré, Abidjan',
        'latitude': 5.3965,
        'longitude': -3.9675,
      },
      'delivery': {
        'name': 'Adresse de livraison',
        'address': 'Riviera Palmeraie, Cocody, Abidjan',
        'latitude': 5.359,
        'longitude': -3.938,
      },
      'courier': {
        'id': 5,
        'full_name': 'Karim Diallo',
        'phone': '+225 07 00 00 00 05',
        'latitude': 5.365,
        'longitude': -3.945,
        'updated_at': '2026-10-26T12:00:00',
      },
      'distance_remaining_km': 1.24,
      'eta_minutes': 5,
      'updated_at': '2026-10-26T12:00:00',
    });

    expect(tracking.orderId, 42);
    expect(tracking.isShipping, isTrue);
    expect(tracking.restaurant.name, 'Chez Mama');
    expect(tracking.delivery.address, contains('Palmeraie'));
    expect(tracking.courier?.fullName, 'Karim Diallo');
    expect(tracking.courier?.hasLocation, isTrue);
    expect(tracking.distanceRemainingKm, 1.24);
    expect(tracking.etaMinutes, 5);
  });

  test('un suivi sans livreur reste exploitable sur la carte', () {
    final tracking = OrderTracking.fromJson({
      'order_id': 43,
      'status': 'pending',
      'restaurant': {
        'name': 'Green Bowl',
        'address': 'Riviera 3, Cocody, Abidjan',
        'latitude': 5.347,
        'longitude': -3.953,
      },
      'delivery': {
        'name': 'Adresse de livraison',
        'address': 'Riviera Palmeraie, Cocody, Abidjan',
        'latitude': 5.359,
        'longitude': -3.938,
      },
      'courier': null,
      'distance_remaining_km': 2.3,
      'eta_minutes': 8,
      'updated_at': '2026-10-26T12:00:00',
    });

    expect(tracking.courier, isNull);
    expect(tracking.isDelivered, isFalse);
    expect(tracking.restaurant.latitude, 5.347);
    expect(tracking.delivery.longitude, -3.938);
  });
}
