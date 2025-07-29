import 'package:flutter/material.dart';
import '../models/item_data.dart';

class InvoiceTotals extends StatefulWidget {
  final List<ItemData> items;
  final double vatPercent;
  final TextEditingController discountCtrl;
  final TextEditingController cashCtrl;

  const InvoiceTotals({
    required this.items,
    required this.vatPercent,
    required this.discountCtrl,
    required this.cashCtrl,
    Key? key,
  }) : super(key: key);

  @override
  _InvoiceTotalsState createState() => _InvoiceTotalsState();
}

class _InvoiceTotalsState extends State<InvoiceTotals> {
  double get subtotal => widget.items.fold(
      0, (sum, it) => sum + it.quantity * it.rate);
  double get vatAmount => widget.items.fold(
      0, (sum, it) => sum + (it.quantity * it.rate * widget.vatPercent / 100));
  double get discount => double.tryParse(widget.discountCtrl.text) ?? 0;
  double get total => subtotal + vatAmount - discount;
  double get cash => double.tryParse(widget.cashCtrl.text) ?? 0;
  double get change => cash - total;

  @override
  void initState() {
    super.initState();
    widget.discountCtrl.addListener(_recalc);
    widget.cashCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    widget.discountCtrl.removeListener(_recalc);
    widget.cashCtrl.removeListener(_recalc);
    super.dispose();
  }

  void _recalc() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Subtotal: ${subtotal.toStringAsFixed(2)}', textAlign: TextAlign.right),
      TextFormField(
        controller: widget.discountCtrl,
        decoration: const InputDecoration(labelText: 'Discount (خصم)'),
        keyboardType: TextInputType.number,
      ),
      Text('VAT ${widget.vatPercent.toStringAsFixed(0)}%: ${vatAmount.toStringAsFixed(2)}', textAlign: TextAlign.right),
      Text('Total: ${total.toStringAsFixed(2)}', textAlign: TextAlign.right),
      const SizedBox(height: 10),
      TextFormField(
        controller: widget.cashCtrl,
        decoration: const InputDecoration(labelText: 'Cash (نقدي) *'),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required field';
          }
          final cashValue = double.tryParse(value) ?? 0;
          if (cashValue <= 0) {
            return 'Must be greater than zero';
          }
          if (cashValue < total) {
            return 'Insufficient cash';
          }
          return null;
        },
      ),
      Text('Change: ${change.toStringAsFixed(2)}', textAlign: TextAlign.right),
      const Divider(),
      Text('Total Items: ${widget.items.length}', textAlign: TextAlign.left),
    ]);
  }
}