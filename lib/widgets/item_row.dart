import 'package:flutter/material.dart';
import '../models/item_data.dart';

class ItemRow extends StatefulWidget {
  final int index;
  final ItemData item;
  final double vatPercent;
  final VoidCallback onDelete;

  const ItemRow({
    required this.index,
    required this.item,
    required this.vatPercent,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  _ItemRowState createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> {
  late TextEditingController _descCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.description);
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _rateCtrl = TextEditingController(text: widget.item.rate.toString());

    _descCtrl.addListener(_updateDescription);
    _qtyCtrl.addListener(_updateQuantity);
    _rateCtrl.addListener(_updateRate);
  }

  @override
  void didUpdateWidget(ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.quantity != oldWidget.item.quantity) {
      _qtyCtrl.text = widget.item.quantity.toString();
    }
    if (widget.item.rate != oldWidget.item.rate) {
      _rateCtrl.text = widget.item.rate.toString();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _updateDescription() {
    widget.item.description = _descCtrl.text;
  }

  void _updateQuantity() {
    widget.item.quantity = double.tryParse(_qtyCtrl.text) ?? 0;
    setState(() {});
  }

  void _updateRate() {
    widget.item.rate = double.tryParse(_rateCtrl.text) ?? 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final itemAmount = widget.item.quantity * widget.item.rate;
    final vatAmount = itemAmount * widget.vatPercent / 100;
    final totalAmount = itemAmount + vatAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  '${widget.index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vatAmount.toStringAsFixed(2),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    totalAmount.toStringAsFixed(2),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: widget.onDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Delete Item / حذف العنصر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}