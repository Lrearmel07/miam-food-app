import 'package:flutter_test/flutter_test.dart';
import 'package:miam/web/portal_app.dart';
import 'package:miam/web/portal_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('le portail partenaire affiche sa connexion dédiée', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PartnerWebApp());
    await tester.pumpAndSettle();

    expect(find.text('Espace Partenaire'), findsWidgets);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('partner@miam.app'), findsOneWidget);
    expect(find.text('Entrer avec le compte démo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le portail admin affiche sa connexion dédiée', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AdminWebApp());
    await tester.pumpAndSettle();

    expect(find.text('Espace Administrateur'), findsWidgets);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('admin@miam.app'), findsOneWidget);
    expect(find.text('Entrer avec le compte démo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('chaque portail possède un rôle et un compte démo distincts', () {
    expect(PortalKind.partner.role, 'partner');
    expect(PortalKind.partner.demoEmail, 'partner@miam.app');
    expect(PortalKind.admin.role, 'admin');
    expect(PortalKind.admin.demoEmail, 'admin@miam.app');
  });
}
