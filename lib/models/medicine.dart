class Medicine {
  final String id;
  final String name;
  final String company;
  final String category;
  final String batchNumber;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final String rack;
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.name,
    required this.company,
    required this.category,
    required this.batchNumber,
    required this.purchaseDate,
    required this.expiryDate,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.rack,
    required this.createdAt,
  });

  // Days until expiry (negative = already expired)
  int get daysUntilExpiry {
    final now = DateTime.now();
    return expiryDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;
  bool get isCritical => daysUntilExpiry >= 0 && daysUntilExpiry <= 7;
  bool get isWarning => daysUntilExpiry > 7 && daysUntilExpiry <= 30;
  bool get isSafe => daysUntilExpiry > 30;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'company': company,
      'category': category,
      'batchNumber': batchNumber,
      'purchaseDate': purchaseDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'rack': rack,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Medicine.fromMap(String id, Map<String, dynamic> map) {
    return Medicine(
      id: id,
      name: map['name'] ?? '',
      company: map['company'] ?? '',
      category: map['category'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      rack: map['rack'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Medicine copyWith({
    String? name,
    String? company,
    String? category,
    String? batchNumber,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    String? rack,
  }) {
    return Medicine(
      id: id,
      name: name ?? this.name,
      company: company ?? this.company,
      category: category ?? this.category,
      batchNumber: batchNumber ?? this.batchNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      rack: rack ?? this.rack,
      createdAt: createdAt,
    );
  }
}