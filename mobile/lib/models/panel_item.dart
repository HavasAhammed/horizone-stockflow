enum PanelStatus { available, sold }

class PanelItem {
  final String id;
  final String serialNumber;
  final String batchNumber;
  final int wattage; // in Watts (W)
  final String purchaseId;
  final double purchasePrice; // in INR
  final PanelStatus status;
  final String? saleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  PanelItem({
    required this.id,
    required this.serialNumber,
    required this.batchNumber,
    required this.wattage,
    required this.purchaseId,
    required this.purchasePrice,
    this.status = PanelStatus.available,
    this.saleId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isAvailable => status == PanelStatus.available;
  bool get isSold => status == PanelStatus.sold;

  PanelItem copyWith({
    String? id,
    String? serialNumber,
    String? batchNumber,
    int? wattage,
    String? purchaseId,
    double? purchasePrice,
    PanelStatus? status,
    String? saleId,
    bool clearSaleId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PanelItem(
      id: id ?? this.id,
      serialNumber: serialNumber ?? this.serialNumber,
      batchNumber: batchNumber ?? this.batchNumber,
      wattage: wattage ?? this.wattage,
      purchaseId: purchaseId ?? this.purchaseId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      status: status ?? this.status,
      saleId: clearSaleId ? null : (saleId ?? this.saleId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serialNumber': serialNumber,
      'batchNumber': batchNumber,
      'wattage': wattage,
      'purchaseId': purchaseId,
      'purchasePrice': purchasePrice,
      'status': status.name,
      'saleId': saleId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PanelItem.fromMap(Map<dynamic, dynamic> map) {
    return PanelItem(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      serialNumber: (map['serialNumber'] ?? '').toString(),
      batchNumber: (map['batchNumber'] ?? '').toString(),
      wattage: ((map['wattage'] ?? 0) as num).toInt(),
      purchaseId: (map['purchaseId'] ?? '').toString(),
      purchasePrice: ((map['purchasePrice'] ?? 0.0) as num).toDouble(),
      status: (map['status']?.toString().toLowerCase()) == 'sold'
          ? PanelStatus.sold
          : PanelStatus.available,
      saleId: map['saleId']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
