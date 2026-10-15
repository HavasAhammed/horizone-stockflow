import 'package:hive_flutter/hive_flutter.dart';
import '../models/purchase.dart';

abstract class PurchaseRepository {
  Future<List<PurchaseTransaction>> getAllPurchases();
  Future<PurchaseTransaction?> getPurchaseById(String id);
  Future<void> savePurchase(PurchaseTransaction purchase);
  Future<void> deletePurchase(String id);
}

class HivePurchaseRepository implements PurchaseRepository {
  static const String boxName = 'purchases_box';

  Box get _box => Hive.box(boxName);

  @override
  Future<List<PurchaseTransaction>> getAllPurchases() async {
    final list =
        _box.values.map((v) => PurchaseTransaction.fromMap(v as Map)).toList();
    list.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return list;
  }

  @override
  Future<PurchaseTransaction?> getPurchaseById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return PurchaseTransaction.fromMap(raw as Map);
  }

  @override
  Future<void> savePurchase(PurchaseTransaction purchase) async {
    await _box.put(purchase.id, purchase.toMap());
  }

  @override
  Future<void> deletePurchase(String id) async {
    await _box.delete(id);
  }
}
