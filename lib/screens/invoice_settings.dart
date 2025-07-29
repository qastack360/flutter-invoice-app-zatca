import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier; // ADDED

  const InvoiceSettingsScreen({Key? key, required this.refreshNotifier}) : super(key: key); // MODIFIED

  @override
  _InvoiceSettingsScreenState createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _startCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _startCtrl.text = (prefs.getInt('startInvoice') ?? 1).toString();
      _vatCtrl.text = (prefs.getDouble('vatPercent') ?? 15).toString();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('startInvoice', int.tryParse(_startCtrl.text) ?? 1);
    await prefs.setDouble('vatPercent', double.tryParse(_vatCtrl.text) ?? 15);

    // ADDED: Trigger refresh
    widget.refreshNotifier.value = !widget.refreshNotifier.value;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Settings'), backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _startCtrl,
              decoration: const InputDecoration(labelText: 'Start Invoice No'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _vatCtrl,
              decoration: const InputDecoration(labelText: 'VAT %'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _save,
                child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}