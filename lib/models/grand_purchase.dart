class GrandPurchase {
  final int? id;
  final int typeId;
  final String? typeName;
  final String name;
  final String? color;
  final double price;
  final DateTime date;
  final String? desc;

  GrandPurchase({
    this.id,
    required this.typeId,
    this.typeName,
    required this.name,
    this.color,
    required this.price,
    required this.date,
    this.desc,
  });

  /// Category name from [typeName] (loaded via JOIN). Empty if not joined yet.
  String get type => typeName ?? '';

  factory GrandPurchase.fromMap(Map<String, dynamic> m) {
    return GrandPurchase(
      id: m['id'] as int?,
      typeId: m['type_id'] as int,
      typeName: m['type_name'] as String?,
      name: m['name'] as String,
      color: m['color'] as String?,
      price: (m['price'] as num).toDouble(),
      date: DateTime.parse(m['date'] as String),
      desc: m['desc'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type_id': typeId,
      'name': name,
      'color': color,
      'price': price,
      'date': date.toIso8601String().split('T').first,
      'desc': desc,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toJson() {
    final json = toMap();
    if (type.isNotEmpty) json['type'] = type;
    return json;
  }

  factory GrandPurchase.fromJson(Map<String, dynamic> json) {
    final typeId = json['type_id'] as int?;
    if (typeId != null) {
      return GrandPurchase.fromMap(json);
    }
    return GrandPurchase(
      id: json['id'] as int?,
      typeId: 0,
      typeName: json['type'] as String?,
      name: json['name'] as String,
      color: json['color'] as String?,
      price: (json['price'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      desc: json['desc'] as String?,
    );
  }
}
