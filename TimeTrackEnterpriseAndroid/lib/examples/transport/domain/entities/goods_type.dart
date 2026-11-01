import 'value_readers.dart';

/// نوع بضاعة من المرجع `/goods/`.
class GoodsType {
  const GoodsType({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.hazardous,
    this.store,
    this.note,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final bool hazardous;
  final String? store;
  final String? note;

  factory GoodsType.fromJson(Map<String, dynamic> json) {
    return GoodsType(
      id: readText(json['id']),
      name: readText(json['name']),
      category: readText(json['cat'], fallback: 'عام'),
      unit: readText(json['unit']),
      hazardous: readFlag(json['haz']),
      store: readTextOrNull(json['store']),
      note: readTextOrNull(json['note']),
    );
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'name': name,
        'cat': category,
        'haz': hazardous ? 1 : 0,
        'unit': unit,
        'store': store ?? '',
        'note': note ?? '',
      };
}
