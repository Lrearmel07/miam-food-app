class Product {
  const Product({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.emoji = '',
    this.imageUrl,
    required this.isAvailable,
    required this.prepTime,
  });

  final int id;
  final int restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String emoji;
  final String? imageUrl;
  final bool isAvailable;
  final int prepTime;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      restaurantId: (json['restaurant_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'Plats',
      emoji: json['emoji'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      prepTime: (json['prep_time'] as num?)?.toInt() ?? 15,
    );
  }
}
