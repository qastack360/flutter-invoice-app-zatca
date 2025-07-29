class ItemData {
  String description;
  double quantity;
  double rate;

  ItemData({
    this.description = '',
    this.quantity = 0,
    this.rate = 0,
  });

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'rate': rate,
  };

  factory ItemData.fromMap(Map<String, dynamic> m) => ItemData(
    description: m['description'] as String,
    quantity: (m['quantity'] as num).toDouble(),
    rate: (m['rate'] as num).toDouble(),
  );
}