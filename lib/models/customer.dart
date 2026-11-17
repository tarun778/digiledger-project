class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final int totalTransactions;
  final double totalSpent;
  final double totalProfit;
  final bool isActive;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.notes,
    required this.totalTransactions,
    required this.totalSpent,
    required this.totalProfit,
    required this.isActive,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      notes: json['notes'] ?? '',
      totalTransactions: json['total_transactions'] ?? 0,
      totalSpent: double.tryParse('${json['total_spent']}') ?? 0,
      totalProfit: double.tryParse('${json['total_profit']}') ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
