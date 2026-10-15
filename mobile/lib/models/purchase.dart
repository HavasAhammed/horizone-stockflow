class PurchaseTransaction {
  final String id;
  final DateTime purchaseDate;
  final String? supplierName;
  final String batchNumber;
  final int wattage; // in Watts (W)
  final int quantity;
  final List<String> serialNumbers;
  final double unitPurchasePrice;
  final double totalPurchaseAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseTransaction({
    required this.id,
    required this.purchaseDate,
    this.supplierName,
    required this.batchNumber,
    required this.wattage,
    required this.quantity,
    required this.serialNumbers,
    required this.unitPurchasePrice,
    required this.totalPurchaseAmount,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PurchaseTransaction copyWith({
    String? id,
    DateTime? purchaseDate,
    String? supplierName,
    String? batchNumber,
    int? wattage,
    int? quantity,
    List<String>? serialNumbers,
    double? unitPurchasePrice,
    double? totalPurchaseAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseTransaction(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      batchNumber: batchNumber ?? this.batchNumber,
      wattage: wattage ?? this.wattage,
      quantity: quantity ?? this.quantity,
      serialNumbers: serialNumbers ?? this.serialNumbers,
      unitPurchasePrice: unitPurchasePrice ?? this.unitPurchasePrice,
      totalPurchaseAmount: totalPurchaseAmount ?? this.totalPurchaseAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseDate': purchaseDate.toIso8601String(),
      'supplierName': supplierName,
      'batchNumber': batchNumber,
      'wattage': wattage,
      'quantity': quantity,
      'serialNumbers': serialNumbers,
      'unitPurchasePrice': unitPurchasePrice,
      'totalPurchaseAmount': totalPurchaseAmount,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PurchaseTransaction.fromMap(Map<dynamic, dynamic> map) {
    return PurchaseTransaction(
      id: map['id'] as String,
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      supplierName: map['supplierName'] as String?,
      batchNumber: map['batchNumber'] as String,
      wattage: map['wattage'] as int,
      quantity: map['quantity'] as int,
      serialNumbers: List<String>.from(map['serialNumbers'] as List),
      unitPurchasePrice: (map['unitPurchasePrice'] as num).toDouble(),
      totalPurchaseAmount: (map['totalPurchaseAmount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
