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
      id: map['id'] as String,
      saleDate: DateTime.parse(map['saleDate'] as String),
      customerId: map['customerId'] as String,
      consumerNumber: map['consumerNumber'] as String,
      customerName: map['customerName'] as String?,
      panelWattage: map['panelWattage'] as int,
      quantity: map['quantity'] as int,
      serialNumbers: List<String>.from(map['serialNumbers'] as List),
      unitSellingPrice: (map['unitSellingPrice'] as num).toDouble(),
      totalSellingAmount: (map['totalSellingAmount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
