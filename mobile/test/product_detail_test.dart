import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miam/core/api_client.dart';
import 'package:miam/core/app_state.dart';
import 'package:miam/core/theme.dart';
import 'package:miam/models/product.dart';
import 'package:miam/models/restaurant.dart';
import 'package:miam/screens/client/restaurant_screen.dart';
import 'package:provider/provider.dart';

const _restaurant = Restaurant(
  id: 1,
  name: 'Chez Mama',
  description: 'Cuisine ivoirienne généreuse.',
  cuisine: 'Ivoirien',
  emoji: '🍲',
  color: '#FF7A45',
  rating: 4.8,
  deliveryFee: 1000,
  minOrder: 5000,
  etaMin: 25,
  address: 'Rue L88, Cocody Angré, Abidjan',
  isOpen: true,
  productCount: 1,
  latitude: 5.3965,
  longitude: -3.9675,
);

const _bissap = Product(
  id: 7,
  restaurantId: 1,
  name: 'Jus de bissap',
  description: 'Hibiscus frais, gingembre et menthe.',
  price: 1500,
  category: 'Boissons',
  emoji: '🧃',
  isAvailable: true,
  prepTime: 5,
);

class _FakeApiClient extends ApiClient {
  @override
  Future<List<Product>> menu(
    int restaurantId, {
    bool includeUnavailable = false,
  }) async {
    return const [_bissap];
  }
}

void main() {
  testWidgets('ouvre la fiche détaillée d’un plat et l’ajoute au panier', (
    tester,
  ) async {
    final state = AppState(api: _FakeApiClient());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildMiamTheme(),
          home: const RestaurantScreen(restaurant: _restaurant),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jus de bissap'), findsOneWidget);

    await tester.tap(find.text('Jus de bissap'));
    await tester.pumpAndSettle();

    expect(find.text('À propos'), findsOneWidget);
    expect(find.text('Hibiscus frais, gingembre et menthe.'), findsNWidgets(2));
    expect(find.text('Boissons'), findsWidgets);
    expect(find.text('5 min'), findsWidgets);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(state.quantityOf(_bissap.id), 1);
    expect(state.cartRestaurant?.id, _restaurant.id);
  });
}
