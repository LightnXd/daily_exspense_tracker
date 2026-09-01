class PurchaseType {
  final int? id;
  final String name;
  final bool useColor;
  final bool deductFromBudget;
  final int sortOrder;

  PurchaseType({
    this.id,
    required this.name,
    this.useColor = false,
    this.deductFromBudget = false,
    this.sortOrder = 0,
  });

  factory PurchaseType.fromMap(Map<String, dynamic> m) {
    return PurchaseType(
      id: m['id'] as int?,
      name: m['name'] as String,
      useColor: (m['use_color'] as int? ?? 0) == 1,
      deductFromBudget: (m['deduct_from_budget'] as int? ?? 0) == 1,
      sortOrder: m['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'use_color': useColor ? 1 : 0,
      'deduct_from_budget': deductFromBudget ? 1 : 0,
      'sort_order': sortOrder,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toJson() => toMap();

  factory PurchaseType.fromJson(Map<String, dynamic> json) =>
      PurchaseType.fromMap(json);
}
