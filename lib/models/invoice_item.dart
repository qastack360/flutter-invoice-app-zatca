class InvoiceItem {
  int? id;
  int invoiceId;
  String description;
  int qty;
  double rate;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.description,
    required this.qty,
    required this.rate,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoiceId': invoiceId,
    'description': description,
    'qty': qty,
    'rate': rate,
  };

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
    id: m['id'] as int?,
    invoiceId: m['invoiceId'] as int,
    description: m['description'] as String,
    qty: m['qty'] as int,
    rate: m['rate'] as double,
  );
}
