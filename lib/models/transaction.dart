class Transaction {
  final int? id;
  final double amount;
  final double serviceCharge;
  final double vat;
  final double balance;
  final DateTime date;
  final String? payer;
  final String? receiver;
  final String? reason;
  final String? url;

  Transaction({
    this.id,
    required this.amount,
    required this.serviceCharge,
    required this.vat,
    required this.balance,
    required this.date,
    this.payer,
    this.receiver,
    this.reason,
    this.url,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'serviceCharge': serviceCharge,
      'vat': vat,
      'balance': balance,
      'date': date.toIso8601String(),
      'payer': payer,
      'receiver': receiver,
      'reason': reason,
      'url': url,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      serviceCharge: map['serviceCharge'],
      vat: map['vat'],
      balance: map['balance'],
      date: DateTime.parse(map['date']),
      payer: map['payer'],
      receiver: map['receiver'],
      reason: map['reason'],
      url: map['url'],
    );
  }
}
