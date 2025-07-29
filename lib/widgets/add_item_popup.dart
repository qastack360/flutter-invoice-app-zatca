import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_data.dart';

class AddItemPopup extends StatefulWidget {
  const AddItemPopup({Key? key}) : super(key: key);
  @override
  _AddItemPopupState createState() => _AddItemPopupState();
}

class _AddItemPopupState extends State<AddItemPopup> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ItemData> _savedItems = [];
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedItems();
  }

  Future<void> _loadSavedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('savedItems') ?? [];
    setState(() {
      _savedItems = list.map((e) {
        final p = e.split('|');
        return ItemData(
          description: p[0].trim(),
          quantity: double.parse(p[1]),
          rate: double.parse(p[2]),
        );
      }).toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Text(
                  'Add Item',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Saved Items'),
                Tab(text: 'New Item'),
              ],
            ),
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSavedList(),
                  _buildNewItemForm(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_tabController.index == 1) {
                        final newItem = ItemData(
                          description: _descCtrl.text.trim(),
                          quantity: double.tryParse(_qtyCtrl.text) ?? 0,
                          rate: double.tryParse(_rateCtrl.text) ?? 0,
                        );
                        Navigator.pop(context, newItem);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Add Item', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedList() {
    return _savedItems.isEmpty
        ? const Center(child: Text('No saved items available', style: TextStyle(fontSize: 16)))
        : ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _savedItems.length,
      itemBuilder: (_, index) {
        final item = _savedItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(item.description),
            subtitle: Text('Qty: ${item.quantity}, Rate: ${item.rate}'),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => Navigator.pop(context, item),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewItemForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final newItem = ItemData(
                description: _descCtrl.text.trim(),
                quantity: double.tryParse(_qtyCtrl.text) ?? 0,
                rate: double.tryParse(_rateCtrl.text) ?? 0,
              );
              final prefs = await SharedPreferences.getInstance();
              final list = _savedItems.map((i) => '${i.description}|${i.quantity}|${i.rate}').toList();
              list.add('${newItem.description}|${newItem.quantity}|${newItem.rate}');
              await prefs.setStringList('savedItems', list);
              Navigator.pop(context, newItem);
            },
            child: const Text('Save & Add Item'),
          ),
        ],
      ),
    );
  }
}