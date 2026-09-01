import '../models/grand_purchase.dart';
import '../models/purchase_type.dart';

String purchaseDisplayName(GrandPurchase p, PurchaseType? type) {
  if (type?.useColor == true && p.color != null && p.color!.isNotEmpty) {
    return '${p.name} - ${p.color}';
  }
  return p.name;
}
