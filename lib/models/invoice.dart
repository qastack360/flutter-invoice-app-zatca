// lib/models/invoice.dart
class Invoice {
  final int? id;
  final int number;
  final String date;
  final String salesman;
  final String customer;
  final String vatNo;

  Invoice({
    this.id,
    required this.number,
    required this.date,
    required this.salesman,
    required this.customer,
    required this.vatNo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'date': date,
    'salesman': salesman,
    'customer': customer,
    'vatNo': vatNo,
  };

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
    id: m['id'] as int?,
    number: m['number'] as int,
    date: m['date'] as String,
    salesman: m['salesman'] as String,
    customer: m['customer'] as String,
    vatNo: m['vatNo'] as String,
  );
}
