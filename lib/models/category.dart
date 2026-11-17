class Category {
  final String id;
  final String name;
  final String icon;
  final String categoryType;
  final bool isCustom;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.categoryType,
    required this.isCustom,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      categoryType: json['category_type'],
      isCustom: json['is_custom'],
      isActive: json['is_active'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
