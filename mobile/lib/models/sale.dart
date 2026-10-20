class SaleTransaction {
  final String id;
  final DateTime saleDate;
  final String customerId;
  final String consumerNumber; // KSEB consumer confirmation
  final String? customerName;
  final int panelWattage; // in Watts (W)
  final int quantity; // derived from serialNumbers.length
  final List<String> serialNumbers;
  final double unitSellingPrice;
  final double totalSellingAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  SaleTransaction({
    required this.id,
    required this.saleDate,
    required this.customerId,
    required this.consumerNumber,
    this.customerName,
    required this.panelWattage,
    required this.quantity,
    required this.serialNumbers,
    required this.unitSellingPrice,
    required this.totalSellingAmount,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  SaleTransaction copyWith({
    String? id,
    DateTime? saleDate,
    String? customerId,
    String? consumerNumber,
    String? customerName,
    int? panelWattage,
    int? quantity,
    List<String>? serialNumbers,
    double? unitSellingPrice,
    double? totalSellingAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleTransaction(
      id: id ?? this.id,
      saleDate: saleDate ?? this.saleDate,
      customerId: customerId ?? this.customerId,
      consumerNumber: consumerNumber ?? this.consumerNumber,
      customerName: customerName ?? this.customerName,
      panelWattage: panelWattage ?? this.panelWattage,
      quantity: quantity ?? this.quantity,
      serialNumbers: serialNumbers ?? this.serialNumbers,
      unitSellingPrice: unitSellingPrice ?? this.unitSellingPrice,
      totalSellingAmount: totalSellingAmount ?? this.totalSellingAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleDate': saleDate.toIso8601String(),
      'customerId': customerId,
      'consumerNumber': consumerNumber,
      'customerName': customerName,
      'panelWattage': panelWattage,
      'quantity': quantity,
      'serialNumbers': serialNumbers,
      'unitSellingPrice': unitSellingPrice,
      'totalSellingAmount': totalSellingAmount,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SaleTransaction.fromMap(Map<dynamic, dynamic> map) {
    return SaleTransaction(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      saleDate: map['saleDate'] != null
          ? DateTime.tryParse(map['saleDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      customerId: (map['customerId'] ?? '').toString(),
      consumerNumber: (map['consumerNumber'] ?? '').toString(),
      customerName: map['customerName'] as String?,
      panelWattage: ((map['panelWattage'] ?? 0) as num).toInt(),
      quantity: ((map['quantity'] ?? 0) as num).toInt(),
      serialNumbers: map['serialNumbers'] != null
          ? List<String>.from((map['serialNumbers'] as List).map((e) => e.toString()))
          : <String>[],
      unitSellingPrice: ((map['unitSellingPrice'] ?? 0.0) as num).toDouble(),
      totalSellingAmount: ((map['totalSellingAmount'] ?? 0.0) as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
