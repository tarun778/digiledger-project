class User {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role;
  final String shop;
  final String shopName;
  final bool isActive;
  final bool isSuperuser;
  final String? subscriptionStatus;
  final String? subscriptionEnd;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.shop,
    required this.shopName,
    required this.isActive,
    this.isSuperuser = false,
    this.subscriptionStatus,
    this.subscriptionEnd,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      phone: json['phone'],
      role: json['role'],
      shop: json['shop'],
      shopName: json['shop_name'],
      isActive: json['is_active'],
      isSuperuser: json['is_superuser'] ?? false,
      subscriptionStatus: json['subscription_status'],
      subscriptionEnd: json['subscription_end'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'shop': shop,
      'shop_name': shopName,
      'is_active': isActive,
      'is_superuser': isSuperuser,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff';
}
