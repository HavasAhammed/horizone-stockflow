import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAllCustomers();
  Future<Customer?> getCustomerById(String id);
  Future<Customer?> getCustomerByConsumerNumber(String consumerNumber);
  Future<void> saveCustomer(Customer customer);
  Future<void> deleteCustomer(String id);
}

class HiveCustomerRepository implements CustomerRepository {
  static const String boxName = 'customers_box';

  Box get _box => Hive.box(boxName);

  @override
  Future<List<Customer>> getAllCustomers() async {
    final list = _box.values.map((v) => Customer.fromMap(v as Map)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Customer.fromMap(raw as Map);
  }

  @override
  Future<Customer?> getCustomerByConsumerNumber(String consumerNumber) async {
    final trimmed = consumerNumber.trim().toLowerCase();
    for (final raw in _box.values) {
      final cust = Customer.fromMap(raw as Map);
      if (cust.consumerNumber.trim().toLowerCase() == trimmed) {
        return cust;
      }
    }
    return null;
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    await _box.put(customer.id, customer.toMap());
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _box.delete(id);
  }
}
