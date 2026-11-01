import 'package:flutter_test/flutter_test.dart';
import 'package:miam/core/app_state.dart';
import 'package:miam/core/geo.dart';
import 'package:miam/models/restaurant.dart';

Restaurant _restaurant({
  required int id,
  required String name,
  required double latitude,
  required double longitude,
  double rating = 4.5,
}) {
  return Restaurant(
    id: id,
    name: name,
    description: '',
    cuisine: 'Test',
    emoji: '🍽️',
    color: '#FF7A45',
    rating: rating,
    deliveryFee: 1000,
    minOrder: 5000,
    etaMin: 20,
    address: name,
    isOpen: true,
    productCount: 3,
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  test('calcule une distance et formate les kilomètres', () {
    expect(
      distanceKmBetween(5.3200, -4.0200, 5.3200, -4.0200),
      closeTo(0, 0.001),
    );
    expect(
      distanceKmBetween(5.3200, -4.0200, 5.3300, -4.0100),
      closeTo(1.57, 0.05),
    );
    expect(formatDistance(0.42), '420 m');
    expect(formatDistance(1.26), '1,3 km');
  });

  test('trie les restaurants du plus proche au plus éloigné', () {
    final state = AppState()
      ..clientLatitude = 5.3200
      ..clientLongitude = -4.0200;
    addTearDown(state.dispose);

    final restaurants = [
      _restaurant(id: 1, name: 'Loin', latitude: 5.4000, longitude: -3.9600),
      _restaurant(id: 2, name: 'Proche', latitude: 5.3210, longitude: -4.0190),
      _restaurant(id: 3, name: 'Milieu', latitude: 5.3500, longitude: -3.9800),
    ];

    final sorted = state.sortByDistance(restaurants);

    expect(sorted.map((restaurant) => restaurant.name).toList(), [
      'Proche',
      'Milieu',
      'Loin',
    ]);
    expect(state.distanceTo(sorted.first), lessThan(0.2));
  });
}
