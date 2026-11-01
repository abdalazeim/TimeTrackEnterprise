class ExampleItem {
  const ExampleItem({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.quantity,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String code;
  final String description;
  final int quantity;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ExampleItem.fromJson(Map<String, dynamic> json) => ExampleItem(
        id: _readInt(json['id']),
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        quantity: _readInt(json['quantity']),
        isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
