// lib/models/saved_item.dart
class SavedItem {
  final int? id;
  final String description;
  final double rate;

  SavedItem({
    this.id,
    required this.description,
    required this.rate,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'rate': rate,
  };

  factory SavedItem.fromMap(Map<String, dynamic> m) => SavedItem(
    id: m['id'] as int?,
    description: m['description'] as String,
    rate: (m['rate'] as num).toDouble(),
  );
}
