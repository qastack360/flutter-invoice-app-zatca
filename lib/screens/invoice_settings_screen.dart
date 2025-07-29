import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/invoice_settings.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const InvoiceSettingsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _InvoiceSettingsScreenState createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startInvoiceController = TextEditingController();
  final _vatPercentController = TextEditingController();
  
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceSettings();
  }

  @override
  void dispose() {
    _startInvoiceController.dispose();
    _vatPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceSettings() async {
    try {
      final settings = await _dbHelper.getSettings();
      setState(() {
        _startInvoiceController.text = settings.startInvoice.toString();
        _vatPercentController.text = settings.vatPercent.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoice settings: $e')),
      );
    }
  }

  Future<void> _saveInvoiceSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final settings = InvoiceSettings(
        id: 1,
        startInvoice: int.parse(_startInvoiceController.text),
        vatPercent: double.parse(_vatPercentController.text),
      );

      await _dbHelper.updateSettings(settings);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.refreshNotifier.value = !widget.refreshNotifier.value;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving invoice settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Settings / إعدادات الفاتورة'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveInvoiceSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice Configuration / تكوين الفاتورة',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              controller: _startInvoiceController,
                              decoration: InputDecoration(
                                labelText: 'Start Invoice Number / رقم الفاتورة الأول *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.format_list_numbered),
                                helperText: 'Starting number for new invoices',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter start invoice number';
                                }
                                final number = int.tryParse(value!);
                                if (number == null || number <= 0) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _vatPercentController,
                              decoration: InputDecoration(
                                labelText: 'VAT Percentage / نسبة الضريبة *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.percent),
                                helperText: 'VAT percentage (e.g., 15 for 15%)',
                                suffixText: '%',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter VAT percentage';
                                }
                                final number = double.tryParse(value!);
                                if (number == null || number < 0 || number > 100) {
                                  return 'Please enter a valid percentage (0-100)';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveInvoiceSettings,
                                icon: Icon(Icons.save),
                                label: Text('Save Invoice Settings / حفظ إعدادات الفاتورة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Information / معلومات',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            ListTile(
                              leading: Icon(Icons.info, color: Colors.blue),
                              title: Text('Invoice Numbering'),
                              subtitle: Text('Invoice numbers will start from the specified number and increment automatically.'),
                            ),
                            ListTile(
                              leading: Icon(Icons.info, color: Colors.blue),
                              title: Text('VAT Calculation'),
                              subtitle: Text('VAT will be calculated automatically based on the specified percentage.'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 