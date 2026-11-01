import 'package:flutter/foundation.dart';

/// Adresse de l'API selon la plateforme.
///
/// On peut aussi la forcer au lancement :
/// `flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1`
class AppConfig {
  const AppConfig._();

  static const String _override = String.fromEnvironment('API_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  static const String appName = 'Miam';
  static const String version = '1.0.0';
}
