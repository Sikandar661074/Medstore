class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double totalDue;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.totalDue,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'totalDue': totalDue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      totalDue: (map['totalDue'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    double? totalDue,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalDue: totalDue ?? this.totalDue,
      createdAt: createdAt,
    );
  }
}


class Payment {
  final String id;
  final String customerId;
  final double amount;
  final DateTime date;
  final String note;

  Payment({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      id: id,
      customerId: map['customerId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
    );
  }
}