import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../utils/export_helper.dart';

class ZatcaHistoryScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const ZatcaHistoryScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _ZatcaHistoryScreenState createState() => _ZatcaHistoryScreenState();
}

class _ZatcaHistoryScreenState extends State<ZatcaHistoryScreen> {
  List<Map<String, dynamic>> _zatcaInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];
  bool _isLoading = true;
  String _selectedEnvironment = 'live'; // Default to live
  final _searchController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final SyncService _syncService = SyncService();
  final ExportHelper _exportHelper = ExportHelper();

  @override
  void initState() {
    super.initState();
    _loadZatcaInvoices();
    widget.refreshNotifier.addListener(_loadZatcaInvoices);
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_loadZatcaInvoices);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadZatcaInvoices() async {
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

      // Filter ZATCA invoices
      _zatcaInvoices = allInvoices.where((invoice) {
        final isZatca = invoice['zatca_invoice'] == true || 
                       invoice['sync_status'] == 'completed' ||
                       invoice['zatca_uuid'] != null;
        final environment = invoice['zatca_environment'] ?? 'live';
        return isZatca && environment == _selectedEnvironment;
      }).toList();

      _filteredInvoices = List.from(_zatcaInvoices);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ZATCA invoices: $e')),
      );
    }
  }

  void _filterInvoices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredInvoices = List.from(_zatcaInvoices);
      } else {
        _filteredInvoices = _zatcaInvoices.where((invoice) {
          return invoice['no'].toString().contains(query) ||
                 invoice['customer'].toString().toLowerCase().contains(query) ||
                 (invoice['zatca_uuid']?.toString().toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _onEnvironmentChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedEnvironment = value;
      });
      _loadZatcaInvoices();
    }
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
          'ZATCA_${_selectedEnvironment}_${DateFormat('yyyy_MM').format(now)}'
        );
      } else {
        fileName = await _exportHelper.exportToPDF(
          monthlyInvoices, 
          'ZATCA_${_selectedEnvironment}_${DateFormat('yyyy_MM').format(now)}'
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
    final zatcaUuid = invoice['zatca_uuid'];
    final qrCode = invoice['zatca_qr_code'];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.orange[700],
          child: Text(
            '${index + 1}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'ZATCA Invoice #${invoice['no']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedEnvironment.toUpperCase(),
                style: TextStyle(
                  color: Colors.orange[800],
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
            if (zatcaUuid != null) ...[
              SizedBox(height: 4),
              Text(
                'ZATCA UUID: ${zatcaUuid.toString().substring(0, 8)}...',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
            if (qrCode != null) ...[
              SizedBox(height: 4),
              Text(
                'QR Code: Available',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ],
            SizedBox(height: 8),
            Text(
              'Total: SAR ${invoice['total'].toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.qr_code, size: 32, color: Colors.blue),
          onPressed: () {
            // Show QR code or ZATCA details
            _showZatcaDetails(invoice);
          },
        ),
      ),
    );
  }

  void _showZatcaDetails(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ZATCA Invoice Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invoice #: ${invoice['no']}'),
              Text('Customer: ${invoice['customer']}'),
              Text('Date: ${invoice['date']}'),
              Text('Total: SAR ${invoice['total'].toStringAsFixed(2)}'),
              if (invoice['zatca_uuid'] != null)
                Text('ZATCA UUID: ${invoice['zatca_uuid']}'),
              if (invoice['zatca_qr_code'] != null)
                Text('QR Code: Available'),
              Text('Environment: ${invoice['zatca_environment'] ?? 'live'}'),
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
        title: Text('ZATCA History / سجل ضريبة القيمة المضافة'),
        backgroundColor: Colors.orange,
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
          // Environment Filter
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environment Filter / فلتر البيئة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedEnvironment,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(value: 'live', child: Text('Live (Production)')),
                      DropdownMenuItem(value: 'sandbox', child: Text('Sandbox (Testing)')),
                    ],
                    onChanged: _onEnvironmentChanged,
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterInvoices(),
              decoration: InputDecoration(
                labelText: 'Search ZATCA invoices...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

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
                              'No ZATCA invoices found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              'Invoices sent to ZATCA will appear here',
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