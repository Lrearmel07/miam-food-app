class ReviewAuthor {
  const ReviewAuthor({required this.id, required this.fullName});

  final int id;
  final String fullName;

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReviewAuthor(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
    );
  }
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.author,
  });

  final int id;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final ReviewAuthor author;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      author: ReviewAuthor.fromJson(json['author'] as Map<String, dynamic>),
    );
  }
}
