import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_line.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/restaurant.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'geo.dart';

/// État global : session, catalogue et panier.
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, this.tokenKey = 'miam_token'})
    : api = api ?? ApiClient();

  final ApiClient api;
  final String tokenKey;

  static const String demoPassword = 'demo1234';
  static const Map<String, String> demoEmails = {
    'client': 'client@miam.app',
    'courier': 'courier@miam.app',
    'partner': 'partner@miam.app',
    'admin': 'admin@miam.app',
  };

  SharedPreferences? _prefs;
  bool _disposed = false;
  User? user;
  bool booting = true;

  List<Restaurant> restaurants = [];
  List<String> cuisines = [];
  bool catalogLoading = false;
  String? catalogError;

  double? clientLatitude;
  double? clientLongitude;
  bool locating = false;
  String? locationError;

  bool get hasClientLocation =>
      clientLatitude != null && clientLongitude != null;

  List<CartLine> cart = [];
  Restaurant? cartRestaurant;
  int clientTabIndex = 0;

  bool get isLoggedIn => user != null;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> updateAvatar(String avatarUrl) async {
    final updated = await api.updateProfile(avatarUrl: avatarUrl);
    user = updated;
    notifyListeners();
  }

  Future<void> restore() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(tokenKey);
    if (stored != null && stored.isNotEmpty) {
      api.setToken(stored);
      try {
        user = await api.me();
      } on ApiException {
        api.setToken(null);
        await _prefs?.remove(tokenKey);
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final session = await api.login(email, password);
    await _applySession(session);
  }

  Future<void> demoLogin(String role) async {
    final email = demoEmails[role];
    if (email == null) {
      throw const ApiException('Compte démo inconnu.');
    }
    await login(email, demoPassword);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final session = await api.register(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    await _applySession(session);
  }

  Future<void> _applySession(AuthSession session) async {
    debugPrint(
      '🔐 [AppState] Login réussi, token: ${session.token.substring(0, 20)}...',
    );

    api.setToken(session.token);
    debugPrint(
      '🔐 [AppState] Token défini dans ApiClient: ${api.token != null}',
    );
    user = session.user;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(tokenKey, session.token);
    cart = [];
    cartRestaurant = null;
    clientTabIndex = 0;
    notifyListeners();
  }

  Future<void> logout() async {
    api.setToken(null);
    user = null;
    cart = [];
    cartRestaurant = null;
    clientTabIndex = 0;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(tokenKey);
    notifyListeners();
  }

  // ------------------------------------------------------------- Catalogue

  Future<void> loadCatalog({bool force = false}) async {
    if (catalogLoading) return;
    if (!force && restaurants.isNotEmpty) return;

    catalogLoading = true;
    catalogError = null;
    notifyListeners();

    try {
      restaurants = await api.restaurants(
        latitude: clientLatitude,
        longitude: clientLongitude,
      );
      cuisines = await api.cuisines();
    } on ApiException catch (error) {
      catalogError = error.message;
    } catch (_) {
      catalogError = 'Impossible de charger les restaurants.';
    } finally {
      catalogLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ Localisation

  Future<void> autoLocate() async {
    if (hasClientLocation || locating) return;
    await _locate(prompt: false);
  }

  Future<bool> activateLocation() => _locate(prompt: true);

  Future<bool> _locate({required bool prompt}) async {
    if (locating) return false;
    locating = true;
    locationError = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationError =
            'La localisation est désactivée. Activez-la dans les réglages.';
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.unableToDetermine && prompt) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied && prompt) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        locationError =
            'Localisation bloquée. Autorisez-la dans les réglages du téléphone.';
        return false;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        if (prompt) {
          locationError = 'Autorisation de localisation refusée.';
        }
        return false;
      }

      var position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setClientLocation(position.latitude, position.longitude);
      return true;
    } catch (_) {
      if (prompt || hasClientLocation) {
        locationError = 'Position indisponible pour le moment.';
      }
      return false;
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  void setClientLocation(double latitude, double longitude) {
    clientLatitude = latitude;
    clientLongitude = longitude;
    locationError = null;
    notifyListeners();
  }

  double? distanceTo(Restaurant restaurant) {
    final latitude = restaurant.latitude;
    final longitude = restaurant.longitude;
    if (hasClientLocation && latitude != null && longitude != null) {
      return distanceKmBetween(
        clientLatitude!,
        clientLongitude!,
        latitude,
        longitude,
      );
    }
    return restaurant.distanceKm;
  }

  List<Restaurant> sortByDistance(List<Restaurant> restaurants) {
    if (!hasClientLocation) return restaurants;
    final sorted = [...restaurants];
    sorted.sort((a, b) {
      final first = distanceTo(a);
      final second = distanceTo(b);
      if (first == null && second == null) {
        return b.rating.compareTo(a.rating);
      }
      if (first == null) return 1;
      if (second == null) return -1;
      final byDistance = first.compareTo(second);
      if (byDistance != 0) return byDistance;
      return b.rating.compareTo(a.rating);
    });
    return sorted;
  }

  // ----------------------------------------------------------------- Panier

  int get cartCount => cart.fold(0, (sum, line) => sum + line.quantity);

  double get cartSubtotal => cart.fold(0.0, (sum, line) => sum + line.total);

  double get cartDeliveryFee =>
      cart.isEmpty ? 0 : cartRestaurant?.deliveryFee ?? 0;

  double get cartTotal => cartSubtotal + cartDeliveryFee;

  int quantityOf(int productId) {
    for (final line in cart) {
      if (line.product.id == productId) return line.quantity;
    }
    return 0;
  }

  /// Renvoie false si le panier contient déjà un autre restaurant.
  bool addToCart(Product product, Restaurant restaurant) {
    if (cart.isNotEmpty && cartRestaurant?.id != restaurant.id) {
      return false;
    }
    cartRestaurant = restaurant;
    for (final line in cart) {
      if (line.product.id == product.id) {
        if (line.quantity < 20) line.quantity++;
        notifyListeners();
        return true;
      }
    }
    cart.add(CartLine(product: product));
    notifyListeners();
    return true;
  }

  void replaceCartWith(Product product, Restaurant restaurant) {
    cart = [CartLine(product: product)];
    cartRestaurant = restaurant;
    notifyListeners();
  }

  void increment(Product product) {
    for (final line in cart) {
      if (line.product.id == product.id) {
        if (line.quantity < 20) line.quantity++;
        notifyListeners();
        return;
      }
    }
  }

  void decrement(Product product) {
    for (final line in cart) {
      if (line.product.id == product.id) {
        if (line.quantity > 1) {
          line.quantity--;
        } else {
          cart.remove(line);
          if (cart.isEmpty) cartRestaurant = null;
        }
        notifyListeners();
        return;
      }
    }
  }

  void removeLine(CartLine line) {
    cart.remove(line);
    if (cart.isEmpty) cartRestaurant = null;
    notifyListeners();
  }

  void clearCart() {
    cart = [];
    cartRestaurant = null;
    notifyListeners();
  }

  Future<FoodOrder> placeOrder({
    required String address,
    String notes = '',
  }) async {
    if (cart.isEmpty || cartRestaurant == null) {
      throw const ApiException('Votre panier est vide.');
    }
    final order = await api.createOrder(
      restaurantId: cartRestaurant!.id,
      items: cart
          .map(
            (line) => {
              'product_id': line.product.id,
              'quantity': line.quantity,
            },
          )
          .toList(),
      address: address,
      notes: notes,
    );
    cart = [];
    cartRestaurant = null;
    clientTabIndex = 1;
    notifyListeners();
    return order;
  }

  Future<void> cancelOrder(int orderId) async {
    await api.cancelOrder(orderId);
  }

  void setClientTab(int index) {
    if (clientTabIndex == index) return;
    clientTabIndex = index;
    notifyListeners();
  }
}
