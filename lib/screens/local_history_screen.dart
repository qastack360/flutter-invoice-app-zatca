import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/export_helper.dart';

class LocalHistoryScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const LocalHistoryScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _LocalHistoryScreenState createState() => _LocalHistoryScreenState();
}

class _LocalHistoryScreenState extends State<LocalHistoryScreen> {
  List<Map<String, dynamic>> _localInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final ExportHelper _exportHelper = ExportHelper();

  @override
  void initState() {
    super.initState();
    _loadLocalInvoices();
    widget.refreshNotifier.addListener(_loadLocalInvoices);
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_loadLocalInvoices);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalInvoices() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load invoices from local storage
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('invoices') ?? [];
      
      List<Map<String, dynamic>> allInvoices = data
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();

      // Filter local invoices (not ZATCA)
      _localInvoices = allInvoices.where((invoice) {
        final isZatca = invoice['zatca_invoice'] == true || 
                       invoice['sync_status'] == 'completed' ||
                       invoice['zatca_uuid'] != null;
        return !isZatca;
      }).toList();

      _filteredInvoices = List.from(_localInvoices);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading local invoices: $e')),
      );
    }
  }

  void _filterInvoices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredInvoices = List.from(_localInvoices);
      } else {
        _filteredInvoices = _localInvoices.where((invoice) {
          return invoice['no'].toString().contains(query) ||
                 invoice['customer'].toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _exportMonthlyData(String format) async {
    try {
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      
      // Filter invoices for current month
      final monthlyInvoices = _filteredInvoices.where((invoice) {
        final invoiceDate = DateTime.tryParse(invoice['date'].split(' – ')[0]);
        return invoiceDate != null && 
               invoiceDate.month == month && 
               invoiceDate.year == year;
      }).toList();

      if (monthlyInvoices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No invoices found for current month')),
        );
        return;
      }

      String fileName;
      if (format == 'csv') {
        fileName = await _exportHelper.exportToCSV(
          monthlyInvoices, 
          'LOCAL_${DateFormat('yyyy_MM').format(now)}'
        );
      } else {
        fileName = await _exportHelper.exportToPDF(
          monthlyInvoices, 
          'LOCAL_${DateFormat('yyyy_MM').format(now)}'
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$format exported successfully: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice, int index) {
    final dateParts = invoice['date'].split(' – ');
    final date = dateParts[0];
    final time = dateParts.length > 1 ? dateParts[1] : '';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[700],
          child: Text(
            '${index + 1}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Local Invoice #${invoice['no']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'LOCAL',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text('Customer: ${invoice['customer']}'),
            Text('Date: $date'),
            if (time.isNotEmpty) Text('Time: $time'),
            SizedBox(height: 8),
            Text(
              'Total: SAR ${invoice['total'].toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.print, size: 32, color: Colors.grey),
          onPressed: () {
            // Show invoice details
            _showInvoiceDetails(invoice);
          },
        ),
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Local Invoice Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invoice #: ${invoice['no']}'),
              Text('Customer: ${invoice['customer']}'),
              Text('Date: ${invoice['date']}'),
              Text('Total: SAR ${invoice['total'].toStringAsFixed(2)}'),
              Text('Type: Local (Offline)'),
              if (invoice['items'] != null) ...[
                SizedBox(height: 8),
                Text('Items: ${invoice['items'].length}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local History / السجل المحلي'),
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'csv') {
                _exportMonthlyData('csv');
              } else if (value == 'pdf') {
                _exportMonthlyData('pdf');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export Monthly CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export Monthly PDF'),
                  ],
                ),
              ),
            ],
            child: Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterInvoices(),
              decoration: InputDecoration(
                labelText: 'Search local invoices...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Invoices List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No local invoices found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              'Offline invoices will appear here',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: 24),
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          return _buildInvoiceCard(invoice, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 