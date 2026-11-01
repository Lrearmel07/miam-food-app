import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/order.dart';
import '../models/order_tracking.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../models/restaurant.dart';
import '../models/chat.dart';
import '../models/user.dart';
import 'config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final User user;
}

/// Toutes les requêtes HTTP vers l'API Miam passent par cette classe.
class ApiClient {
  ApiClient({String? baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 10),
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token != null && token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String? token;

  void setToken(String? value) => token = value;

  // ----------------------------------------------------------------- Avis

  Future<List<Review>> reviews(int restaurantId) async {
    final response = await _request(
      () => _dio.get<dynamic>('/restaurants/$restaurantId/reviews'),
    );
    return _asList(
      response.data,
    ).map((item) => Review.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<User> updateProfile({String? avatarUrl}) async {
    final response = await _request(
      () => _dio.patch<dynamic>(
        '/auth/me',
        data: {if (avatarUrl != null) 'avatar_url': avatarUrl},
      ),
    );
    return User.fromJson(_asMap(response.data));
  }

  Future<Review> createReview(
    int restaurantId, {
    required int rating,
    required String comment,
  }) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/restaurants/$restaurantId/reviews',
        data: {'rating': rating, 'comment': comment},
      ),
    );
    return Review.fromJson(response.data as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------- Chatbot

  Future<ChatReply> chat(String message) async {
    final response = await _request(
      () => _dio.post<dynamic>('/chat/message', data: {'message': message}),
    );
    final data = response.data as Map<String, dynamic>;
    return ChatReply.fromJson(data);
  }

  // ---------------------------------------------------------------- Auth

  Future<AuthSession> login(String email, String password) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      ),
    );
    return _sessionFrom(response.data);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone,
        },
      ),
    );
    return _sessionFrom(response.data);
  }

  Future<User> me() async {
    final response = await _request(() => _dio.get<dynamic>('/auth/me'));
    return User.fromJson(_asMap(response.data));
  }

  // ------------------------------------------------------------- Catalogue

  Future<List<Restaurant>> restaurants({
    String? query,
    String? cuisine,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _request(
      () => _dio.get<dynamic>(
        '/restaurants',
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine,
          if (latitude != null && longitude != null) 'latitude': latitude,
          if (latitude != null && longitude != null) 'longitude': longitude,
        },
      ),
    );
    return _asList(
      response.data,
    ).map((item) => Restaurant.fromJson(_asMap(item))).toList();
  }

  Future<List<String>> cuisines() async {
    final response = await _request(() => _dio.get<dynamic>('/cuisines'));
    return _asList(response.data).map((item) => item as String).toList();
  }

  Future<List<Product>> menu(
    int restaurantId, {
    bool includeUnavailable = false,
  }) async {
    final response = await _request(
      () => _dio.get<dynamic>(
        '/restaurants/$restaurantId/menu',
        queryParameters: {'include_unavailable': includeUnavailable},
      ),
    );
    return _asList(
      response.data,
    ).map((item) => Product.fromJson(_asMap(item))).toList();
  }

  // ------------------------------------------------------------- Commandes

  Future<FoodOrder> createOrder({
    required int restaurantId,
    required List<Map<String, int>> items,
    required String address,
    String notes = '',
  }) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/orders',
        data: {
          'restaurant_id': restaurantId,
          'items': items,
          'address': address.trim(),
          'notes': notes.trim(),
        },
      ),
    );
    return FoodOrder.fromJson(_asMap(response.data));
  }

  Future<List<FoodOrder>> orders() async {
    final response = await _request(() => _dio.get<dynamic>('/orders'));
    return _asList(
      response.data,
    ).map((item) => FoodOrder.fromJson(_asMap(item))).toList();
  }

  Future<FoodOrder> cancelOrder(int orderId) async {
    final response = await _request(
      () => _dio.post<dynamic>('/orders/$orderId/cancel'),
    );
    return FoodOrder.fromJson(_asMap(response.data));
  }

  Future<OrderTracking> orderTracking(int orderId) async {
    final response = await _request(
      () => _dio.get<dynamic>('/orders/$orderId/tracking'),
    );
    return OrderTracking.fromJson(_asMap(response.data));
  }

  // ---------------------------------------------------------------- Livreur

  Future<List<FoodOrder>> courierAvailable() async {
    final response = await _request(
      () => _dio.get<dynamic>('/courier/available'),
    );
    return _asList(
      response.data,
    ).map((item) => FoodOrder.fromJson(_asMap(item))).toList();
  }

  Future<List<FoodOrder>> courierOrders() async {
    final response = await _request(() => _dio.get<dynamic>('/courier/orders'));
    return _asList(
      response.data,
    ).map((item) => FoodOrder.fromJson(_asMap(item))).toList();
  }

  Future<FoodOrder> acceptOrder(int orderId) async {
    final response = await _request(
      () => _dio.post<dynamic>('/courier/orders/$orderId/accept'),
    );
    return FoodOrder.fromJson(_asMap(response.data));
  }

  Future<FoodOrder> deliverOrder(int orderId) async {
    final response = await _request(
      () => _dio.post<dynamic>('/courier/orders/$orderId/deliver'),
    );
    return FoodOrder.fromJson(_asMap(response.data));
  }

  Future<OrderTracking> updateCourierLocation(
    int orderId, {
    required double latitude,
    required double longitude,
  }) async {
    final response = await _request(
      () => _dio.patch<dynamic>(
        '/courier/orders/$orderId/location',
        data: {'latitude': latitude, 'longitude': longitude},
      ),
    );
    return OrderTracking.fromJson(_asMap(response.data));
  }

  Future<Map<String, dynamic>> courierStats() async {
    final response = await _request(() => _dio.get<dynamic>('/courier/stats'));
    return _asMap(response.data);
  }

  // ------------------------------------------------------------- Partenaire

  Future<Restaurant> partnerRestaurant() async {
    final response = await _request(
      () => _dio.get<dynamic>('/partner/restaurant'),
    );
    return Restaurant.fromJson(_asMap(response.data));
  }

  Future<Restaurant> updatePartnerRestaurant(Map<String, dynamic> data) async {
    final response = await _request(
      () => _dio.patch<dynamic>('/partner/restaurant', data: data),
    );
    return Restaurant.fromJson(_asMap(response.data));
  }

  Future<List<FoodOrder>> partnerOrders() async {
    final response = await _request(() => _dio.get<dynamic>('/partner/orders'));
    return _asList(
      response.data,
    ).map((item) => FoodOrder.fromJson(_asMap(item))).toList();
  }

  Future<FoodOrder> updatePartnerOrderStatus(int orderId, String status) async {
    final response = await _request(
      () => _dio.patch<dynamic>(
        '/partner/orders/$orderId/status',
        data: {'status': status},
      ),
    );
    return FoodOrder.fromJson(_asMap(response.data));
  }

  Future<List<Product>> partnerProducts() async {
    final response = await _request(
      () => _dio.get<dynamic>('/partner/products'),
    );
    return _asList(
      response.data,
    ).map((item) => Product.fromJson(_asMap(item))).toList();
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await _request(
      () => _dio.post<dynamic>('/partner/products', data: data),
    );
    return Product.fromJson(_asMap(response.data));
  }

  Future<Product> updateProduct(
    int productId,
    Map<String, dynamic> data,
  ) async {
    final response = await _request(
      () => _dio.patch<dynamic>('/partner/products/$productId', data: data),
    );
    return Product.fromJson(_asMap(response.data));
  }

  Future<void> deleteProduct(int productId) async {
    await _request(() => _dio.delete<dynamic>('/partner/products/$productId'));
  }

  Future<Map<String, dynamic>> partnerStats() async {
    final response = await _request(() => _dio.get<dynamic>('/partner/stats'));
    return _asMap(response.data);
  }

  // -------------------------------------------------------------- Uploads

  /// Upload d'un fichier depuis un chemin local (mobile uniquement).
  Future<String> uploadImage({
    required String filePath,
    required String fileName,
  }) async {
    final ext = fileName.toLowerCase().split('.').last;
    MediaType? mediaType;
    if (ext == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (ext == 'webp') {
      mediaType = MediaType('image', 'webp');
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mediaType = MediaType('image', 'jpeg');
    } else if (ext == 'gif') {
      mediaType = MediaType('image', 'gif');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: mediaType,
      ),
    });

    final response = await _request(
      () => _dio.post<dynamic>('/uploads', data: formData),
    );

    final map = _asMap(response.data);
    return map['image_url'] as String;
  }

  /// Upload depuis des bytes (fonctionne sur Flutter Web ET mobile).
  Future<String> uploadImageBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final ext = fileName.toLowerCase().split('.').last;
    MediaType? mediaType;
    if (ext == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (ext == 'webp') {
      mediaType = MediaType('image', 'webp');
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mediaType = MediaType('image', 'jpeg');
    } else if (ext == 'gif') {
      mediaType = MediaType('image', 'gif');
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: mediaType,
      ),
    });

    final response = await _request(
      () => _dio.post<dynamic>('/uploads', data: formData),
    );

    final map = _asMap(response.data);
    return map['image_url'] as String;
  }

  // -------------------------------------------------- Galerie partenaire

  Future<List<Map<String, dynamic>>> partnerRestaurantGallery() async {
    final response = await _request(
      () => _dio.get<dynamic>('/partner/restaurant/gallery'),
    );
    return _asList(response.data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addPartnerRestaurantImage(
    String imageUrl,
  ) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/partner/restaurant/gallery',
        data: {'image_url': imageUrl},
      ),
    );
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> publicRestaurantGallery(
    int restaurantId,
  ) async {
    final response = await _request(
      () => _dio.get<dynamic>('/restaurants/$restaurantId/gallery'),
    );
    return _asList(response.data).cast<Map<String, dynamic>>();
  }

  Future<void> deletePartnerRestaurantImage(int imageId) async {
    await _request(
      () => _dio.delete<dynamic>('/partner/restaurant/gallery/$imageId'),
    );
  }

  Future<void> reorderPartnerRestaurantGallery(List<int> items) async {
    await _request(
      () => _dio.post<dynamic>(
        '/partner/restaurant/gallery/reorder',
        data: {'items': items},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> partnerProductGallery(
    int productId,
  ) async {
    final response = await _request(
      () => _dio.get<dynamic>('/partner/products/$productId/gallery'),
    );
    return _asList(response.data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addPartnerProductImage(
    int productId,
    String imageUrl,
  ) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/partner/products/$productId/gallery',
        data: {'image_url': imageUrl},
      ),
    );
    return _asMap(response.data);
  }

  Future<void> deletePartnerProductImage(int imageId) async {
    await _request(
      () => _dio.delete<dynamic>('/partner/products/gallery/$imageId'),
    );
  }

  Future<void> reorderPartnerProductGallery(List<int> items) async {
    await _request(
      () => _dio.post<dynamic>(
        '/partner/products/gallery/reorder',
        data: {'items': items},
      ),
    );
  }

  // -------------------------------------------------------- Admin

  Future<Map<String, dynamic>> adminStats() async {
    final response = await _request(() => _dio.get<dynamic>('/admin/stats'));
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> adminRestaurantGallery(
    int restaurantId,
  ) async {
    final response = await _request(
      () => _dio.get<dynamic>('/admin/restaurants/$restaurantId/gallery'),
    );
    return _asList(response.data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addAdminRestaurantImage(
    int restaurantId,
    String imageUrl,
  ) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/admin/restaurants/$restaurantId/gallery',
        data: {'image_url': imageUrl},
      ),
    );
    return _asMap(response.data);
  }

  Future<void> deleteAdminRestaurantImage(int imageId) async {
    await _request(
      () => _dio.delete<dynamic>('/admin/restaurants/gallery/$imageId'),
    );
  }

  Future<void> reorderAdminRestaurantGallery(List<int> items) async {
    await _request(
      () => _dio.post<dynamic>(
        '/admin/restaurants/gallery/reorder',
        data: {'items': items},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> adminProductGallery(int productId) async {
    final response = await _request(
      () => _dio.get<dynamic>('/admin/products/$productId/gallery'),
    );
    return _asList(response.data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addAdminProductImage(
    int productId,
    String imageUrl,
  ) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/admin/products/$productId/gallery',
        data: {'image_url': imageUrl},
      ),
    );
    return _asMap(response.data);
  }

  Future<void> deleteAdminProductImage(int imageId) async {
    await _request(
      () => _dio.delete<dynamic>('/admin/products/gallery/$imageId'),
    );
  }

  Future<void> reorderAdminProductGallery(List<int> items) async {
    await _request(
      () => _dio.post<dynamic>(
        '/admin/products/gallery/reorder',
        data: {'items': items},
      ),
    );
  }

  Future<List<User>> adminUsers() async {
    final response = await _request(() => _dio.get<dynamic>('/admin/users'));
    return _asList(
      response.data,
    ).map((item) => User.fromJson(_asMap(item))).toList();
  }

  Future<User> setUserActive(int userId, bool isActive) async {
    final response = await _request(
      () => _dio.patch<dynamic>(
        '/admin/users/$userId/active',
        data: {'is_active': isActive},
      ),
    );
    return User.fromJson(_asMap(response.data));
  }

  Future<List<Restaurant>> adminRestaurants() async {
    final response = await _request(
      () => _dio.get<dynamic>('/admin/restaurants'),
    );
    return _asList(
      response.data,
    ).map((item) => Restaurant.fromJson(_asMap(item))).toList();
  }

  Future<Restaurant> createRestaurant(Map<String, dynamic> data) async {
    final response = await _request(
      () => _dio.post<dynamic>('/admin/restaurants', data: data),
    );
    return Restaurant.fromJson(_asMap(response.data));
  }

  Future<Restaurant> updateRestaurant(
    int restaurantId,
    Map<String, dynamic> data,
  ) async {
    final response = await _request(
      () => _dio.patch<dynamic>('/admin/restaurants/$restaurantId', data: data),
    );
    return Restaurant.fromJson(_asMap(response.data));
  }

  Future<List<FoodOrder>> adminOrders() async {
    final response = await _request(() => _dio.get<dynamic>('/admin/orders'));
    return _asList(
      response.data,
    ).map((item) => FoodOrder.fromJson(_asMap(item))).toList();
  }

  Future<FoodOrder> adminUpdateOrderStatus(int orderId, String status) async {
    final response = await _request(
      () => _dio.patch<dynamic>(
        '/admin/orders/$orderId/status',
        data: {'status': status},
      ),
    );
    return FoodOrder.fromJson(_asMap(response.data));
  }

  Future<User> adminCreatePartner({
    required String email,
    required String password,
    required String fullName,
    required String restaurantName,
    required String cuisine,
    String? phone,
  }) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/admin/partners',
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone,
          'restaurant_name': restaurantName.trim(),
          'cuisine': cuisine,
        },
      ),
    );
    return User.fromJson(_asMap(response.data));
  }

  // ----------------------------------------------------------------- Helpers

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  AuthSession _sessionFrom(dynamic data) {
    final map = _asMap(data);
    return AuthSession(
      token: map['access_token'] as String? ?? '',
      user: User.fromJson(_asMap(map['user'])),
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException('Réponse du serveur inattendue.');
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    throw const ApiException('Réponse du serveur inattendue.');
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout =>
        'Le serveur met trop de temps à répondre.',
      DioExceptionType.connectionError || DioExceptionType.unknown =>
        "Impossible de joindre le serveur. Vérifiez que l'API est lancée.",
      DioExceptionType.badCertificate => 'Connexion sécurisée impossible.',
      DioExceptionType.cancel => 'Requête annulée.',
      DioExceptionType.badResponse => switch (error.response?.statusCode) {
        401 => 'Email ou mot de passe incorrect.',
        403 => 'Accès refusé.',
        404 => 'Élément introuvable.',
        409 => 'Cette action est impossible pour le moment.',
        422 => 'Vérifiez les informations saisies.',
        _ => 'Le serveur a rencontré un problème.',
      },
    };
  }
}
