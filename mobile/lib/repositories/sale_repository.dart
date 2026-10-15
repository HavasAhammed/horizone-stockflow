import 'package:hive_flutter/hive_flutter.dart';
import '../models/sale.dart';

abstract class SaleRepository {
  Future<List<SaleTransaction>> getAllSales();
  Future<SaleTransaction?> getSaleById(String id);
  Future<List<SaleTransaction>> getSalesByCustomerId(String customerId);
  Future<void> saveSale(SaleTransaction sale);
  Future<void> deleteSale(String id);
}

class HiveSaleRepository implements SaleRepository {
  static const String boxName = 'sales_box';

  Box get _box => Hive.box(boxName);

  @override
  Future<List<SaleTransaction>> getAllSales() async {
    final list = _box.values.map((v) => SaleTransaction.fromMap(v as Map)).toList();
    list.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return list;
  }

  @override
  Future<SaleTransaction?> getSaleById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return SaleTransaction.fromMap(raw as Map);
  }

  @override
  Future<List<SaleTransaction>> getSalesByCustomerId(String customerId) async {
    final list = _box.values
        .map((v) => SaleTransaction.fromMap(v as Map))
        .filter((s) => s.customerId == customerId)
        .toList();
    list.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return list;
  }

  @override
  Future<void> saveSale(SaleTransaction sale) async {
    await _box.put(sale.id, sale.toMap());
  }

  @override
  Future<void> deleteSale(String id) async {
    await _box.delete(id);
  }
}

extension _IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T element) test) => where(test);
}
