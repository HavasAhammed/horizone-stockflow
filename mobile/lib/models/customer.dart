class Customer {
  final String id;
  final String consumerNumber; // KSEB consumer number (mandatory)
  final String phone; // Phone number (mandatory)
  final String? name;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.consumerNumber,
    required this.phone,
    this.name,
    this.address,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Customer copyWith({
    String? id,
    String? consumerNumber,
    String? phone,
    String? name,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      consumerNumber: consumerNumber ?? this.consumerNumber,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'consumerNumber': consumerNumber,
      'phone': phone,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<dynamic, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      consumerNumber: map['consumerNumber'] as String,
      phone: map['phone'] as String,
      name: map['name'] as String?,
      address: map['address'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
