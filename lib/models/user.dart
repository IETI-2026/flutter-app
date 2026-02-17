class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final String? phone;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.phone,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'CLIENT',
      isActive: json['isActive'] ?? true,
      phone: json['phone'],
      profileImageUrl: json['profileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'isActive': isActive,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
    };
  }

  bool get isClient => role == 'CLIENT';
  bool get isProvider => role == 'PROVIDER';
}
