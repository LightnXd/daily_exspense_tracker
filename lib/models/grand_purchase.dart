class GrandPurchase {
  final int? id;
  final String type;
  final String name;
  final String? color;
  final int price;
  final DateTime date;
  final String? desc;

  GrandPurchase({
    this.id,
    required this.type,
    required this.name,
    this.color,
    required this.price,
    required this.date,
    this.desc,
  });

  /// Returns "name - color" for sanitation when color is set, otherwise just "name".
  String get displayName =>
      (type == 'sanitation' && color != null && color!.isNotEmpty)
          ? '$name - $color'
          : name;

  factory GrandPurchase.fromMap(Map<String, dynamic> m) {
    return GrandPurchase(
      id: m['id'] as int?,
      type: m['type'] as String,
      name: m['name'] as String,
      color: m['color'] as String?,
      price: m['price'] as int,
      date: DateTime.parse(m['date'] as String),
      desc: m['desc'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'name': name,
      'color': color,
      'price': price,
      'date': date.toIso8601String().split('T').first,
      'desc': desc,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
