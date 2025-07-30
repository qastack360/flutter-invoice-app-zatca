import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/item_data.dart';
import 'zatca_history_screen.dart';
import 'local_history_screen.dart';
import 'invoice_preview_screen.dart';

class CategorizedHistoryScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const CategorizedHistoryScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _CategorizedHistoryScreenState createState() => _CategorizedHistoryScreenState();
}

class _CategorizedHistoryScreenState extends State<CategorizedHistoryScreen> {
  List<Map<String, dynamic>> _allInvoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllInvoices();
    widget.refreshNotifier.addListener(_refreshData);
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_refreshData);
    super.dispose();
  }

  void _refreshData() {
    _loadAllInvoices();
  }

  Future<void> _loadAllInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('invoices') ?? [];
      setState(() {
        _allInvoices = data.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoices: $e')),
      );
    }
  }

  int _getZatcaInvoiceCount() {
    return _allInvoices.where((invoice) => 
      invoice['zatca_invoice'] == true || 
      invoice['sync_status'] == 'completed'
    ).length;
  }

  int _getLocalInvoiceCount() {
    return _allInvoices.where((invoice) => 
      invoice['zatca_invoice'] != true && 
      invoice['sync_status'] != 'completed'
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice History / سجل الفواتير'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  _buildSummaryCard(),
                  SizedBox(height: 20),

                  // Categories
                  _buildHistoryCategories(),
                  SizedBox(height: 20),

                  // Recent Invoices
                  _buildRecentInvoices(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final zatcaCount = _getZatcaInvoiceCount();
    final localCount = _getLocalInvoiceCount();
    final totalCount = _allInvoices.length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Summary / ملخص الفواتير',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Invoices',
                    totalCount.toString(),
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'ZATCA Invoices',
                    zatcaCount.toString(),
                    Icons.cloud_done,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Local Invoices',
                    localCount.toString(),
                    Icons.storage,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryCategories() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'History Categories / فئات السجل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildCategoryTile(
              icon: Icons.cloud_done,
              title: 'ZATCA History / سجل ضريبة القيمة المضافة',
              subtitle: '${_getZatcaInvoiceCount()} invoices synced with ZATCA',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ZatcaHistoryScreen(refreshNotifier: widget.refreshNotifier),
                ),
              ),
            ),
            Divider(),
            _buildCategoryTile(
              icon: Icons.storage,
              title: 'Local History / السجل المحلي',
              subtitle: '${_getLocalInvoiceCount()} offline invoices',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocalHistoryScreen(refreshNotifier: widget.refreshNotifier),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildRecentInvoices() {
    final recentInvoices = _allInvoices
        .take(5)
        .toList();

    if (recentInvoices.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No invoices yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                Text(
                  'Create your first invoice to see it here',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Invoices / الفواتير الأخيرة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...recentInvoices.map((invoice) => _buildRecentInvoiceTile(invoice)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentInvoiceTile(Map<String, dynamic> invoice) {
    final isZatca = invoice['zatca_invoice'] == true || invoice['sync_status'] == 'completed';
    final invoiceNumber = '${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}';
    final customerName = invoice['customer'] ?? 'Unknown';
    final date = invoice['date'] ?? '';
    final totalAmount = _calculateTotalAmount(invoice);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isZatca ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        child: Icon(
          isZatca ? Icons.cloud_done : Icons.storage,
          color: isZatca ? Colors.green : Colors.orange,
        ),
      ),
      title: Text(
        invoiceNumber,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(customerName),
          Text(
            date,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'SAR ${totalAmount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isZatca ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isZatca ? 'ZATCA' : 'Local',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      onTap: () => _showInvoicePreview(invoice),
    );
  }

  double _calculateTotalAmount(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    final totalAmount = items.fold<double>(0, (sum, item) => sum + (item.quantity * item.rate));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final discount = invoice['discount'] ?? 0.0;
    
    return totalAmount + vatAmount - discount;
  }

  void _showInvoicePreview(Map<String, dynamic> invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(
          invoice: invoice,
          refreshNotifier: widget.refreshNotifier,
        ),
      ),
    );
  }
} 