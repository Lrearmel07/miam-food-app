import '../core/format.dart';

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.isActive = true,
    this.avatarUrl,
  });

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final bool isActive;
  final String? avatarUrl;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Utilisateur',
      phone: (json['phone'] as String?)?.trim(),
      role: json['role'] as String? ?? 'client',
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  String get firstName => fullName.split(' ').first;
  String get initials => initialsOf(fullName);
  String get roleLabelText => roleLabel(role);
}
