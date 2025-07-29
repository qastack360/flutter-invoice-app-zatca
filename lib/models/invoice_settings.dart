// lib/models/invoice_settings.dart
class InvoiceSettings {
  final int id;
  final int startInvoice;
  final double vatPercent;

  InvoiceSettings({
    required this.id,
    required this.startInvoice,
    required this.vatPercent,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'startInvoice': startInvoice,
    'vatPercent': vatPercent,
  };

  factory InvoiceSettings.fromMap(Map<String, dynamic> m) => InvoiceSettings(
    id: m['id'] as int,
    startInvoice: m['startInvoice'] as int,
    vatPercent: (m['vatPercent'] as num).toDouble(),
  );
}
