import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miam/app.dart';
import 'package:miam/core/app_state.dart';
import 'package:miam/core/format.dart';
import 'package:miam/core/theme.dart';
import 'package:miam/models/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('affiche l’écran de connexion au démarrage', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MiamApp());
    await tester.pumpAndSettle();

    expect(find.text('Miam'), findsOneWidget);
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Partenaire'), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  testWidgets('un partenaire connecté sur mobile est renvoyé vers le web', (
    tester,
  ) async {
    final state = AppState()
      ..booting = false
      ..user = const User(
        id: 1,
        email: 'partner@miam.app',
        fullName: 'Mama Adjoua',
        role: 'partner',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: buildMiamTheme(), home: const RootGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Espace Partenaire'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  test('les montants sont affichés en FCFA sans décimales', () {
    final formatted = money(9500);
    expect(formatted, endsWith(' FCFA'));
    expect(formatted, isNot(contains(',')));
    expect(formatted.replaceAll(RegExp(r'\D'), ''), '9500');
  });

  test('les statuts de commande sont traduits en français', () {
    expect(statusLabel('pending'), 'En attente');
    expect(statusLabel('preparing'), 'En préparation');
    expect(statusLabel('shipping'), 'En livraison');
    expect(statusLabel('delivered'), 'Livrée');
    expect(statusLabel('inconnu'), 'inconnu');
  });
}
