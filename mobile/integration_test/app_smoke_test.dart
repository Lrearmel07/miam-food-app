import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miam/app.dart';
import 'package:miam/core/app_state.dart';
import 'package:miam/widgets/common.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Élément introuvable après $timeout : $finder');
}

Future<void> _startLoggedOut(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await tester.pumpWidget(const MiamApp());
  await _waitFor(tester, find.text('Bon retour !'));
}

Future<void> _quickLogin(WidgetTester tester, String role) async {
  final button = find.text(role);
  await tester.ensureVisible(button);
  await tester.tap(button);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('le compte client arrive sur l’accueil', (tester) async {
    await _startLoggedOut(tester);
    await _quickLogin(tester, 'Client');
    await _waitFor(tester, find.byType(RestaurantTile));
    expect(find.text('Accueil'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le client trie les restaurants autour de sa position', (
    tester,
  ) async {
    await _startLoggedOut(tester);
    await _quickLogin(tester, 'Client');
    await _waitFor(tester, find.byType(RestaurantTile));

    final state = Provider.of<AppState>(
      tester.element(find.byType(RestaurantTile).first),
      listen: false,
    );
    state.setClientLocation(5.3200, -4.0200);
    await tester.pump();

    await _waitFor(tester, find.text('Les plus proches'));
    await _waitFor(tester, find.textContaining('Le plus proche à'));

    final tiles = tester
        .widgetList<RestaurantTile>(find.byType(RestaurantTile))
        .toList();
    expect(tiles, isNotEmpty);
    expect(tiles.first.restaurant.name, 'Maquis du Plateau');
    expect(tiles.first.distanceKm, isNotNull);
  });

  testWidgets('le client fait défiler les publicités', (tester) async {
    await _startLoggedOut(tester);
    await _quickLogin(tester, 'Client');
    await _waitFor(tester, find.byType(RestaurantTile));
    await _waitFor(tester, find.text('Envie de bon ?'));

    await tester.drag(find.byType(PageView), const Offset(-380, 0));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('Bissap & douceurs'));
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(PageView), const Offset(-380, 0));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('Votre repas arrive'));
    expect(find.text('Mes commandes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le compte livreur arrive sur ses courses', (tester) async {
    await _startLoggedOut(tester);
    await _quickLogin(tester, 'Livreur');
    await _waitFor(tester, find.text('Courses disponibles'));
    expect(find.text('Courses'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le client ouvre le suivi cartographique de sa livraison', (
    tester,
  ) async {
    await _startLoggedOut(tester);
    await _quickLogin(tester, 'Client');
    await _waitFor(tester, find.byType(RestaurantTile));

    final ordersTab = find.text('Commandes').last;
    await tester.ensureVisible(ordersTab);
    await tester.tap(ordersTab);
    await _waitFor(tester, find.text('Mes commandes'));
    await _waitFor(tester, find.text('Suivre'));

    final follow = find.text('Suivre').first;
    await tester.ensureVisible(follow);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(follow, warnIfMissed: false);
    await tester.pumpAndSettle();
    await _waitFor(
      tester,
      find.textContaining('Suivi · commande'),
      timeout: const Duration(seconds: 15),
    );
    await _waitFor(
      tester,
      find.text('En livraison'),
      timeout: const Duration(seconds: 15),
    );
    expect(find.text('Karim Diallo'), findsWidgets);
    expect(find.text('Itinéraire'), findsOneWidget);
  });

  testWidgets('le livreur peut simuler le partage de sa position', (
    tester,
  ) async {
    await _startLoggedOut(tester);
    await _quickLogin(tester, 'Livreur');
    await _waitFor(tester, find.text('Courses disponibles'));

    final deliveriesTab = find.text('Livraisons').last;
    await tester.ensureVisible(deliveriesTab);
    await tester.tap(deliveriesTab);
    await _waitFor(tester, find.text('Mes livraisons'));
    await _waitFor(tester, find.text('Suivi'));

    final tracking = find.text('Suivi').first;
    await tester.ensureVisible(tracking);
    await tester.tap(tracking);
    await _waitFor(tester, find.textContaining('Position · course'));
    await _waitFor(tester, find.text('Simuler le trajet (démo)'));

    await tester.tap(find.text('Simuler le trajet (démo)'));
    await _waitFor(tester, find.text('Simulation active'));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Arrêter le partage'), findsOneWidget);
    await tester.tap(find.text('Arrêter le partage'));
    await _waitFor(tester, find.text('Partager ma position GPS'));
  });
}
