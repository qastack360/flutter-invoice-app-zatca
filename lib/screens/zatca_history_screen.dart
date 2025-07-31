import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../models/item_data.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../utils/export_helper.dart';
import '../utils/monthly_report_helper.dart';
import '../utils/invoice_helper.dart';
import '../services/qr_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'invoice_preview_screen.dart';

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
  final MonthlyReportHelper _monthlyReportHelper = MonthlyReportHelper();
  final BluetoothPrinterService _bluetoothPrinterService = BluetoothPrinterService();
  final QRService _qrService = QRService();

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

      // Load ZATCA invoices from Supabase server
      List<Map<String, dynamic>> serverInvoices = [];
      try {
        serverInvoices = await _supabaseService.loadInvoices();
        // Normalize server data structure to match local structure
        serverInvoices = serverInvoices.map((invoice) {
          return {
            'no': invoice['invoice_number'] ?? '',
            'invoice_prefix': invoice['invoice_prefix'] ?? '',
            'date': invoice['invoice_date'] ?? '',
            'customer': invoice['customer_name'] ?? '',
            'salesman': invoice['salesman'] ?? '',
            'vatNo': invoice['vat_number'] ?? '',
            'total': invoice['total_amount'] ?? 0.0,
            'vatAmount': invoice['vat_amount'] ?? 0.0,
            'subtotal': invoice['subtotal'] ?? 0.0,
            'discount': invoice['discount'] ?? 0.0,
            'cash': invoice['cash'] ?? 0.0,
            'items': invoice['items'] != null ? jsonDecode(invoice['items']) : [],
            'company': invoice['company_details'] != null ? jsonDecode(invoice['company_details']) : {},
            'zatca_invoice': invoice['zatca_invoice'] ?? false,
            'zatca_uuid': invoice['zatca_uuid'] ?? '',
            'zatca_environment': invoice['zatca_environment'] ?? 'live',
            'zatca_response': invoice['zatca_response'] ?? '',
            'sync_status': invoice['sync_status'] ?? 'pending',
            'created_at': invoice['created_at'] ?? '',
            'id': invoice['id'] ?? '',
          };
        }).toList();
        
        // Filter for ZATCA invoices only
        serverInvoices = serverInvoices.where((invoice) {
          final isZatca = invoice['zatca_invoice'] == true;
          final environment = invoice['zatca_environment'] ?? 'live';
          return isZatca && environment == _selectedEnvironment;
        }).toList();
      } catch (e) {
        print('Error loading from server: $e');
        // Fallback to local storage if server fails
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getStringList('invoices') ?? [];
        
        List<Map<String, dynamic>> allInvoices = data
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();

        // Filter ZATCA invoices
        serverInvoices = allInvoices.where((invoice) {
          final isZatca = invoice['zatca_invoice'] == true || 
                         invoice['sync_status'] == 'completed' ||
                         invoice['zatca_uuid'] != null;
          final environment = invoice['zatca_environment'] ?? 'live';
          return isZatca && environment == _selectedEnvironment;
        }).toList();
      }

      _zatcaInvoices = serverInvoices;
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
            'ZATCA_${_selectedEnvironment}_${DateFormat('yyyy_MM').format(now)}'
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
            'ZATCA_${_selectedEnvironment}_${DateFormat('yyyy_MM').format(now)}'
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
              onPressed: () => _printInvoice(invoice),
            ),
            IconButton(
              icon: Icon(Icons.qr_code, size: 32, color: Colors.blue),
              onPressed: () {
                // Show QR code or ZATCA details
                _showZatcaDetails(invoice);
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
        content: Text('Are you sure you want to delete this ZATCA invoice? This action cannot be undone.'),
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
      // Delete from server if it's a ZATCA invoice
      if (invoice['zatca_invoice'] == true && invoice['id'] != null) {
        await _supabaseService.deleteInvoice(invoice['id']);
        print('Invoice deleted from server successfully');
      }

      // Remove from local list
      setState(() {
        _zatcaInvoices.removeWhere((inv) => inv['no'] == invoice['no'] && inv['date'] == invoice['date']);
        _filteredInvoices.removeWhere((inv) => inv['no'] == invoice['no'] && inv['date'] == invoice['date']);
      });

      // Also remove from local storage if exists
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

  void _showZatcaDetails(Map<String, dynamic> invoice) {
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
        title: Text('ZATCA Invoice Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invoice #: ${invoice['no']}'),
              Text('Customer: ${invoice['customer']}'),
              Text('Date: ${invoice['date']}'),
              Text('Total SAR: ${finalAmount.toStringAsFixed(2)}'),
              Text('Type: ZATCA Invoice'),
              if (invoice['zatca_uuid'] != null)
                Text('ZATCA UUID: ${invoice['zatca_uuid']}'),
              if (invoice['zatca_qr_code'] != null)
                Text('QR Code: Available'),
              Text('Environment: ${invoice['zatca_environment'] ?? 'live'}'),
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
      print('Print button clicked for ZATCA invoice: ${invoice['no']}');
      
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
                      'ZATCA Invoice Preview (Mock Mode)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text('Invoice #: ${invoice['invoice_prefix'] ?? 'ZATCA'}-${invoice['no']}'),
                    Text('Customer: ${invoice['customer']}'),
                    Text('Date: ${invoice['date']}'),
                    Text('Total: SAR ${(invoice['total'] ?? 0.0).toStringAsFixed(2)}'),
                    if (invoice['zatca_uuid'] != null) 
                      Text('ZATCA UUID: ${invoice['zatca_uuid']}'),
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
        invoiceNumber: '${invoice['invoice_prefix'] ?? 'ZATCA'}-${invoice['no']}',
        invoiceData: invoice,
        qrData: QRService.generateSimplifiedZatcaQRData(invoice),
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
    content.writeln('ZATCA INVOICE');
    content.writeln('Invoice #: ${invoice['no']}');
    content.writeln('Date: ${invoice['date']}');
    content.writeln('Customer: ${invoice['customer']}');
    content.writeln('Total SAR: ${finalAmount.toStringAsFixed(2)}');
    if (invoice['zatca_uuid'] != null) {
      content.writeln('ZATCA UUID: ${invoice['zatca_uuid']}');
    }
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
          _loadZatcaInvoices();
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

  // Monthly reporting functionality
  Future<void> _generateMonthlyXML() async {
    try {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString();
      
      // Filter invoices for current month
      final monthlyInvoices = _filteredInvoices.where((invoice) {
        final invoiceDate = DateTime.tryParse(invoice['date'].split(' – ')[0]);
        return invoiceDate != null && 
               invoiceDate.month == now.month && 
               invoiceDate.year == now.year;
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
          title: Text('Generating Monthly XML...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating XML files for ZATCA compliance...'),
            ],
          ),
        ),
      );

      final xmlDirPath = await _monthlyReportHelper.generateMonthlyXMLFiles(
        monthlyInvoices, month, year
      );

      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('XML files generated successfully!\nLocation: $xmlDirPath'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating XML: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createMonthlyZIP() async {
    try {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString();
      
      // Filter invoices for current month
      final monthlyInvoices = _filteredInvoices.where((invoice) {
        final invoiceDate = DateTime.tryParse(invoice['date'].split(' – ')[0]);
        return invoiceDate != null && 
               invoiceDate.month == now.month && 
               invoiceDate.year == now.year;
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
          title: Text('Creating ZIP Archive...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating ZIP file for email submission...'),
            ],
          ),
        ),
      );

      // First generate XML files
      final xmlDirPath = await _monthlyReportHelper.generateMonthlyXMLFiles(
        monthlyInvoices, month, year
      );

      // Then create ZIP
      final zipPath = await _monthlyReportHelper.createMonthlyZIP(
        xmlDirPath, month, year
      );

      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ZIP file created successfully!\nReady for email: $zipPath'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating ZIP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createPrintableSummary() async {
    try {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString();
      
      // Filter invoices for current month
      final monthlyInvoices = _filteredInvoices.where((invoice) {
        final invoiceDate = DateTime.tryParse(invoice['date'].split(' – ')[0]);
        return invoiceDate != null && 
               invoiceDate.month == now.month && 
               invoiceDate.year == now.year;
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
          title: Text('Creating Summary...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating printable summary document...'),
            ],
          ),
        ),
      );

      final summaryPath = await _monthlyReportHelper.createPrintableSummary(
        monthlyInvoices, month, year
      );

      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Summary created successfully!\nLocation: $summaryPath'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ZATCA History'),
        backgroundColor: Colors.green,
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
          // Monthly reporting buttons
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'xml':
                  _generateMonthlyXML();
                  break;
                case 'zip':
                  _createMonthlyZIP();
                  break;
                case 'summary':
                  _createPrintableSummary();
                  break;
                case 'csv':
                  _exportMonthlyData('csv');
                  break;
                case 'pdf':
                  _exportMonthlyData('pdf');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'xml',
                child: Row(
                  children: [
                    Icon(Icons.code, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Generate XML Files'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'zip',
                child: Row(
                  children: [
                    Icon(Icons.archive, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Create ZIP for Email'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'summary',
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Printable Summary'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export PDF'),
                  ],
                ),
              ),
            ],
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
                          return _buildInvoiceListItem(invoice);
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 