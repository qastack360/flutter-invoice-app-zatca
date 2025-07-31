import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../models/item_data.dart';
import '../utils/export_helper.dart';
import '../services/supabase_service.dart';
import '../utils/invoice_helper.dart';
import '../services/qr_service.dart';
import 'invoice_preview_screen.dart';

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
  final SupabaseService _supabaseService = SupabaseService();

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

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Exporting $format...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we generate your $format file...'),
            ],
          ),
        ),
      );

      String fileName;
      if (format == 'csv') {
        try {
          fileName = await _exportHelper.exportToCSV(
            monthlyInvoices, 
            'Local_${DateFormat('yyyy_MM').format(now)}'
          );
        } catch (e) {
          Navigator.of(context).pop(); // Close loading dialog
          if (e.toString().contains('web')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV export not supported on web. Please use PDF export instead.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV export failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        try {
          fileName = await _exportHelper.exportToPDF(
            monthlyInvoices, 
            'Local_${DateFormat('yyyy_MM').format(now)}'
          );
        } catch (e) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF export failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      Navigator.of(context).pop(); // Close loading dialog

      // Show success message with file location
      String message;
      if (fileName.startsWith('data:')) {
        // Web platform - PDF data URL
        message = 'PDF generated successfully! Click to download.';
      } else {
        // Mobile/Desktop platform - file path
        message = '$format exported successfully!\nFile: $fileName';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: fileName.startsWith('data:') ? SnackBarAction(
            label: 'Download',
            onPressed: () {
              // Handle web download
              // You can implement web download logic here
            },
          ) : null,
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildInvoiceListItem(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    final totalAmount = items.fold<double>(0, (sum, item) => sum + ((item?.quantity ?? 0) * (item?.rate ?? 0)));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final discount = invoice['discount'] ?? 0.0;
    final finalAmount = totalAmount + vatAmount - discount;

    final date = invoice['date'] ?? '';
    final time = invoice['time'] ?? '';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          'Invoice #${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${invoice['customer']}'),
            if (date.isNotEmpty) Text('Date: $date'),
            if (time.isNotEmpty) Text('Time: $time'),
            SizedBox(height: 8),
            Text(
              'Total SAR: ${finalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.print, color: Colors.green),
              onPressed: () async {
                print('Print button pressed for invoice ${invoice['no']}');
                await _printInvoice(invoice);
              },
            ),
            IconButton(
              icon: Icon(Icons.qr_code, size: 32, color: Colors.blue),
              onPressed: () {
                // Show QR code or invoice details
                _showInvoiceDetails(invoice);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteInvoice(invoice),
            ),
          ],
        ),
        onTap: () => _showInvoicePreview(invoice),
      ),
    );
  }

  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Invoice'),
        content: Text('Are you sure you want to delete this local invoice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove from local list
      setState(() {
        _localInvoices.removeWhere((inv) => inv['no'] == invoice['no'] && inv['date'] == invoice['date']);
        _filteredInvoices.removeWhere((inv) => inv['no'] == invoice['no'] && inv['date'] == invoice['date']);
      });

      // Remove from local storage
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('invoices') ?? [];
      final updatedData = data.where((s) {
        final inv = jsonDecode(s) as Map<String, dynamic>;
        return !(inv['no'] == invoice['no'] && inv['date'] == invoice['date']);
      }).toList();
      await prefs.setStringList('invoices', updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    final totalAmount = items.fold<double>(0, (sum, item) => sum + ((item?.quantity ?? 0) * (item?.rate ?? 0)));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final discount = invoice['discount'] ?? 0.0;
    final finalAmount = totalAmount + vatAmount - discount;

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
              Text('Total SAR: ${finalAmount.toStringAsFixed(2)}'),
              Text('Type: Invoice (Offline)'),
              if (invoice['items'] != null) ...[
                SizedBox(height: 8),
                Text('Items: ${invoice['items'].length}'),
                SizedBox(height: 8),
                // Items Table with VAT Amount
                Container(
                  width: double.maxFinite,
                  child: DataTable(
                    columnSpacing: 8,
                    columns: [
                      DataColumn(label: Text('Sr', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Description', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Qty', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Rate', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('VAT', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Total', style: TextStyle(fontSize: 12))),
                    ],
                    rows: (invoice['items'] as List<dynamic>).asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final itemData = ItemData.fromMap(item as Map<String, dynamic>);
                      final itemTotal = itemData.quantity * itemData.rate;
                      final itemVat = itemTotal * (invoice['vatPercent'] ?? 15) / 100;
                      final itemTotalWithVat = itemTotal + itemVat;
                      return DataRow(cells: [
                        DataCell(Text('${index + 1}', style: TextStyle(fontSize: 11))),
                        DataCell(Text(itemData.description, style: TextStyle(fontSize: 11))),
                        DataCell(Text(itemData.quantity.toString(), style: TextStyle(fontSize: 11))),
                        DataCell(Text('SAR ${itemData.rate.toStringAsFixed(2)}', style: TextStyle(fontSize: 11))),
                        DataCell(Text('SAR ${itemVat.toStringAsFixed(2)}', style: TextStyle(fontSize: 11))),
                        DataCell(Text('SAR ${itemTotalWithVat.toStringAsFixed(2)}', style: TextStyle(fontSize: 11))),
                      ]);
                    }).toList(),
                  ),
                ),
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

  Future<void> _printInvoice(Map<String, dynamic> invoice) async {
    try {
      print('Print button clicked for invoice: ${invoice['no']}');
      
      // Check mock printing setting
      final prefs = await SharedPreferences.getInstance();
      final mockPrinting = prefs.getBool('mockPrinting') ?? false;
      
      print('Mock printing setting: $mockPrinting');
      
      if (mockPrinting) {
        print('Mock mode ON - showing preview');
        // Show preview for mock printing
        final imageData = await _generateInvoiceImage(invoice);
        if (imageData != null) {
          print('Image generated successfully, showing dialog');
          await showDialog(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    color: Colors.white,
                    child: Image.memory(imageData),
                  ),
                ),
              ),
            ),
          );
        } else {
          print('Failed to generate image, showing error');
          // Show a simple text preview as fallback
          await showDialog(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(10),
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Invoice Preview (Mock Mode)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text('Invoice #: ${invoice['invoice_prefix'] ?? 'INV_NO'}-${invoice['no']}'),
                    Text('Customer: ${invoice['customer']}'),
                    Text('Date: ${invoice['date']}'),
                    Text('Total: SAR ${(invoice['total'] ?? 0.0).toStringAsFixed(2)}'),
                    SizedBox(height: 20),
                    Text(
                      'This is a mock preview. In real printing, this would be sent to the thermal printer.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        print('Mock mode OFF - checking printer connection');
        // Check if printer is connected for real printing
        final isConnected = await _checkPrinterConnection();
        
        if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Printer not connected. Please connect a printer first.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Generate invoice content for printing
        final invoiceContent = _generateInvoiceContent(invoice);
        
        // TODO: Implement actual printing logic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice printed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('Print error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Generate invoice image for preview
  Future<Uint8List?> _generateInvoiceImage(Map<String, dynamic> invoice) async {
    try {
      // Generate PDF with invoice data
      final Uint8List pdfBytes = await InvoiceHelper.generatePdf(
        invoiceNumber: '${invoice['invoice_prefix'] ?? 'INV_NO'}-${invoice['no']}',
        invoiceData: invoice,
        qrData: QRService.generatePrintQRData(invoice), // Use existing QR data for local invoices
        customerName: invoice['customer'] ?? '',
        date: invoice['date'] ?? '',
        items: (invoice['items'] as List<dynamic>).map((item) => item as Map<String, dynamic>).toList(),
        total: (invoice['total'] ?? 0.0).toDouble(),
        vatAmount: (invoice['vatAmount'] ?? 0.0).toDouble(),
        subtotal: (invoice['subtotal'] ?? 0.0).toDouble(),
        discount: (invoice['discount'] ?? 0.0).toDouble(),
        vatPercent: (invoice['vatPercent'] ?? 15.0).toString(),
        companyDetails: (invoice['company'] as Map<String, dynamic>?) ?? {},
        salesman: invoice['salesman'] ?? '',
        cash: invoice['cash']?.toString() ?? '',
        customer: invoice['customer'] ?? '',
        vatNo: invoice['vatNo'] ?? '',
      );

      // Open and render using pdfx
      final doc = await pdfx.PdfDocument.openData(pdfBytes);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: (page.width * 3).toDouble(),
        height: (page.height * 3).toDouble(),
      );

      final imageData = pageImage?.bytes;
      await page.close();
      await doc.close();

      return imageData;
    } catch (e) {
      print('Error generating invoice image: $e');
      return null;
    }
  }

  Future<bool> _checkPrinterConnection() async {
    // TODO: Implement printer connection check
    // For now, return false to show the "not connected" message
    return false;
  }

  String _generateInvoiceContent(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    final totalAmount = items.fold<double>(0, (sum, item) => sum + ((item?.quantity ?? 0) * (item?.rate ?? 0)));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final discount = invoice['discount'] ?? 0.0;
    final finalAmount = totalAmount + vatAmount - discount;

    StringBuffer content = StringBuffer();
            content.writeln('LOCAL INVOICE');
    content.writeln('Invoice #: ${invoice['no']}');
    content.writeln('Date: ${invoice['date']}');
    content.writeln('Customer: ${invoice['customer']}');
    content.writeln('Total SAR: ${finalAmount.toStringAsFixed(2)}');
            content.writeln('Type: Local (Offline)');
    return content.toString();
  }

  // Sync single invoice to ZATCA
  Future<void> _syncSingleInvoice(Map<String, dynamic> invoice) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Syncing invoice to ZATCA...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );

      // Call the ZATCA Edge Function
      final response = await _supabaseService.callZatcaEdgeFunction(invoice);
      
      if (response['success'] == true) {
        // Update local invoice with ZATCA response
        await _updateInvoiceWithZatcaResponse(invoice, response);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice synced successfully to ZATCA!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the list
        setState(() {
          _loadLocalInvoices();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${response['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update invoice with ZATCA response
  Future<void> _updateInvoiceWithZatcaResponse(Map<String, dynamic> invoice, Map<String, dynamic> response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final invoices = prefs.getStringList('invoices') ?? [];
      
      // Find and update the specific invoice
      for (int i = 0; i < invoices.length; i++) {
        final invoiceData = jsonDecode(invoices[i]);
        if (invoiceData['no'] == invoice['no'] && 
            invoiceData['date'] == invoice['date'] &&
            invoiceData['customer'] == invoice['customer']) {
          
          // Update with ZATCA response
          invoiceData['zatca_uuid'] = response['uuid'];
          invoiceData['zatca_qr_code'] = response['qr_code'];
          invoiceData['sync_status'] = 'completed';
          invoiceData['zatca_response'] = response;
          invoiceData['synced_at'] = DateTime.now().toIso8601String();
          invoiceData['zatca_invoice'] = true; // Mark as ZATCA invoice
          
          // Save back to SharedPreferences
          invoices[i] = jsonEncode(invoiceData);
          await prefs.setStringList('invoices', invoices);
          break;
        }
      }
    } catch (e) {
      print('Error updating invoice: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local History / السجل المحلي'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final mockPrinting = prefs.getBool('mockPrinting') ?? false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Mock Mode: ${mockPrinting ? "ON" : "OFF"}'),
                  backgroundColor: mockPrinting ? Colors.green : Colors.orange,
                ),
              );
            },
          ),
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
                labelText: 'Search Local invoices...',
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
                              'No Local invoices found',
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
                          return _buildInvoiceListItem(invoice);
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 