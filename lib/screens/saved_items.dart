// lib/screens/saved_items.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_data.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({Key? key}) : super(key: key);
  @override
  _SavedItemsScreenState createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  List<ItemData> _saved = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('savedItems') ?? [];
    setState(() {
      _saved = list.map((e) {
        final p = e.split('|');
        return ItemData(
          description: p[0],
          quantity: double.parse(p[1]),
          rate: double.parse(p[2]),
        );
      }).toList();
    });
  }

  Future<void> _addSaved() async {
    final desc = TextEditingController();
    final qty = TextEditingController();
    final rate = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Saved Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty')),
            TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final item = ItemData(
              description: desc.text,
              quantity: double.tryParse(qty.text) ?? 0,
              rate: double.tryParse(rate.text) ?? 0,
            );
            _saved.add(item);
            final prefs = await SharedPreferences.getInstance();
            final list = _saved.map((i) => '${i.description}|${i.quantity}|${i.rate}').toList();
            await prefs.setStringList('savedItems', list);
            setState(() {});
            Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _deleteSaved(int i) async {
    _saved.removeAt(i);
    final prefs = await SharedPreferences.getInstance();
    final list = _saved.map((i) => '${i.description}|${i.quantity}|${i.rate}').toList();
    await prefs.setStringList('savedItems', list);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Items'), backgroundColor: Colors.blue),
      body: Column(children: [
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(8),
          child: Row(children: const [
            Expanded(child: Text('SrNo', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: 40),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _saved.length,
            itemBuilder: (_, i) {
              final it = _saved[i];
              return ListTile(
                title: Row(children: [
                  Expanded(child: Text('${i+1}')),
                  Expanded(flex: 3, child: Text(it.description)),
                  Expanded(child: Text(it.quantity.toStringAsFixed(0))),
                  Expanded(child: Text(it.rate.toStringAsFixed(2))),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteSaved(i)),
                ]),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSaved,
        child: const Icon(Icons.add),
      ),
    );
  }
}