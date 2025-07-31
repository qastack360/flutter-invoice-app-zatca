import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../models/item_data.dart';
import '../utils/invoice_helper.dart';
import '../services/printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/supabase_service.dart';
import '../services/qr_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert';

class InvoicePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final ValueNotifier<bool> refreshNotifier;

  const InvoicePreviewScreen({
    Key? key, 
    required this.invoice, 
    required this.refreshNotifier
  }) : super(key: key);

  @override
  _InvoicePreviewScreenState createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final PrinterService _printerService = PrinterService();
  final BluetoothPrinterService _bluetoothPrinterService = BluetoothPrinterService();
  final SupabaseService _supabaseService = SupabaseService();
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    final totalAmount = items.fold<double>(0, (sum, item) => sum + (item.quantity * item.rate));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final discount = invoice['discount'] ?? 0.0;
    final cash = invoice['cash'] ?? 0.0;
    final finalAmount = totalAmount + vatAmount - discount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Details / تفاصيل الفاتورة'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _printInvoice,
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareInvoice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice Header
            _buildInvoiceHeader(invoice),
            SizedBox(height: 20),

            // Customer Details
            _buildCustomerDetails(invoice),
            SizedBox(height: 20),

            // Items Table
            _buildItemsTable(items, invoice),
            SizedBox(height: 20),

            // Totals
            _buildTotals(totalAmount, vatAmount, discount, cash, finalAmount, invoice),
            SizedBox(height: 20),

            // ZATCA Information
            if (invoice['zatca_invoice'] == true) _buildZatcaInfo(invoice),
            
            // QR Code for all invoices
            _buildQRCodeSection(invoice),
            
            // Print Status
            if (_isPrinting) _buildPrintingStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(Map<String, dynamic> invoice) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INVOICE / فاتورة',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Invoice #: ${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              'Date: ${invoice['date']}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              'Salesman: ${invoice['salesman']}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDetails(Map<String, dynamic> invoice) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Details / تفاصيل العميل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Name: ${invoice['customer']}'),
            if (invoice['customerVat']?.isNotEmpty == true)
              Text('VAT: ${invoice['customerVat']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(List<ItemData> items, Map<String, dynamic> invoice) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items / العناصر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(0.5),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.5),
              },
              border: TableBorder.all(color: Colors.grey[300]!),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('Sr')),
                    Padding(padding: EdgeInsets.all(8), child: Text('Description')),
                    Padding(padding: EdgeInsets.all(8), child: Text('Qty')),
                    Padding(padding: EdgeInsets.all(8), child: Text('Rate')),
                    Padding(padding: EdgeInsets.all(8), child: Text('VAT')),
                    Padding(padding: EdgeInsets.all(8), child: Text('Total')),
                  ],
                ),
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final itemTotal = item.quantity * item.rate;
                  final itemVat = itemTotal * (invoice['vatPercent'] ?? 15) / 100;
                  final itemTotalWithVat = itemTotal + itemVat;
                  return TableRow(
                    children: [
                      Padding(padding: EdgeInsets.all(8), child: Text('${index + 1}')),
                      Padding(padding: EdgeInsets.all(8), child: Text(item.description)),
                      Padding(padding: EdgeInsets.all(8), child: Text(item.quantity.toString())),
                      Padding(padding: EdgeInsets.all(8), child: Text('SAR ${item.rate.toStringAsFixed(2)}')),
                      Padding(padding: EdgeInsets.all(8), child: Text('SAR ${itemVat.toStringAsFixed(2)}')),
                      Padding(padding: EdgeInsets.all(8), child: Text('SAR ${itemTotalWithVat.toStringAsFixed(2)}')),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(double totalAmount, double vatAmount, double discount, double cash, double finalAmount, Map<String, dynamic> invoice) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Totals / المجاميع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal:'),
                Text('SAR ${totalAmount.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('VAT (${invoice['vatPercent'] ?? 15}%):'),
                Text('SAR ${vatAmount.toStringAsFixed(2)}'),
              ],
            ),
            if (discount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discount:'),
                  Text('-SAR ${discount.toStringAsFixed(2)}'),
                ],
              ),
            ],
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total SAR:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('SAR ${finalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (cash > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cash Received:'),
                  Text('SAR ${cash.toStringAsFixed(2)}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Change:'),
                  Text('SAR ${(cash - finalAmount).toStringAsFixed(2)}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildZatcaInfo(Map<String, dynamic> invoice) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ZATCA Verification Status / حالة تأكيد ضريبة القيمة المضافة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            // ZATCA Verification Status (thermal-friendly colors)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.black, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'ZATCA Verified Invoice',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text('ZATCA UUID: ${invoice['zatca_uuid']}'),
            Text('Environment: ${invoice['zatca_environment']}'),
            Text('Sync Status: ${invoice['sync_status']}'),
            Text('Status: ${_getZatcaStatus(invoice)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(Map<String, dynamic> invoice) {
    final isZatcaInvoice = invoice['zatca_invoice'] == true;
    final hasZatcaUUID = invoice['zatca_uuid'] != null;
    
    return Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Code / رمز QR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 12),
            
            if (isZatcaInvoice && !hasZatcaUUID) ...[
              // ZATCA invoice without UUID - show message
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code, color: Colors.black, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'ZATCA Invoice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'QR code will be generated after ZATCA verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Click Print to verify with ZATCA and generate QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Local invoice or ZATCA invoice with UUID - show QR code
              Center(
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<Uint8List?>(
                    future: QRService.generateQRImage(QRService.generateZatcaQRData(invoice)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator(color: Colors.black);
                      } else if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        );
                      } else {
                        return Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              'QR Code\nNot Available',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                isZatcaInvoice 
                  ? 'Scan this QR code to verify invoice with ZATCA'
                  : 'Scan this QR code to verify invoice details',
                style: TextStyle(fontSize: 12, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrintingStatus() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printing Status / حالة الطباعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Invoice is being printed...',
              style: TextStyle(fontSize: 14, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoice() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      // Check mock printing setting
      final prefs = await SharedPreferences.getInstance();
      final mockPrinting = prefs.getBool('mockPrinting') ?? false;
      
      print('Invoice Preview - Mock printing setting: $mockPrinting');
      
      if (mockPrinting) {
        print('Mock mode ON - showing preview');
        // Show preview for mock printing
        final imageData = await _generateInvoiceImage();
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
          print('Failed to generate image, showing fallback');
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
                      'Thermal Print Preview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    // Thermal-style layout
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Company Header
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  widget.invoice['company']?['ownerName1'] ?? 'Company Name',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                  textAlign: TextAlign.center,
                                ),
                                if (widget.invoice['company']?['phone'] != null)
                                  Text(
                                    'Phone: ${widget.invoice['company']['phone']}',
                                    style: TextStyle(fontSize: 12, color: Colors.black),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          // ZATCA Verification (if ZATCA invoice)
                          if (widget.invoice['zatca_invoice'] == true && widget.invoice['zatca_uuid'] != null) ...[
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.black, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'ZATCA Verified Invoice',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                          ],

                          // Invoice Details
                          Text(
                            'Invoice #: ${widget.invoice['invoice_prefix'] ?? 'INV'}-${widget.invoice['no']}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          Text(
                            'Customer: ${widget.invoice['customer']}',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                          Text(
                            'Total: SAR ${(widget.invoice['total'] ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                          SizedBox(height: 16),

                          // QR Code placeholder
                          Center(
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  'QR Code\n(150x150)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'This is a thermal printer preview. In real printing, this would be sent to the thermal printer.',
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

        // Get invoice data
        final invoice = widget.invoice;
        final items = (invoice['items'] as List<dynamic>)
            .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
            .toList();
        
        final totalAmount = items.fold<double>(0, (sum, item) => sum + (item.quantity * item.rate));
        final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
        final discount = invoice['discount'] ?? 0.0;
        final finalAmount = totalAmount + vatAmount - discount;

        // Print the invoice using the bluetooth service
        await _bluetoothPrinterService.printInvoice(
          invoiceNumber: '${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}',
          invoiceData: invoice,
          qrData: QRService.generatePrintQRData(invoice),
          customerName: invoice['customer'],
          date: invoice['date'],
          items: items.map((item) => item.toMap()).toList(),
          total: finalAmount,
          vatAmount: vatAmount,
          subtotal: totalAmount,
          discount: discount,
          vatPercent: (invoice['vatPercent'] ?? 15.0).toString(),
          companyDetails: {}, // TODO: Load company details
        );
        
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
    } finally {
      setState(() {
        _isPrinting = false;
      });
    }
  }

  // Generate invoice image for preview
  Future<Uint8List?> _generateInvoiceImage() async {
    try {
      final invoice = widget.invoice;
      final items = (invoice['items'] as List<dynamic>)
          .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
          .toList();
      
      final totalAmount = items.fold<double>(0, (sum, item) => sum + (item.quantity * item.rate));
      final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
      final discount = invoice['discount'] ?? 0.0;
      final finalAmount = totalAmount + vatAmount - discount;

      // Generate PDF with invoice data
      final Uint8List pdfBytes = await InvoiceHelper.generatePdf(
        invoiceNumber: '${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}',
        invoiceData: invoice,
        qrData: QRService.generatePrintQRData(invoice),
        customerName: invoice['customer'] ?? '',
        date: invoice['date'] ?? '',
        items: items.map((item) => item.toMap()).toList(),
        total: finalAmount,
        vatAmount: vatAmount,
        subtotal: totalAmount,
        discount: discount,
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

  Future<void> _shareInvoice() async {
    // Generate PDF and share
    try {
      final pdfBytes = await _generateInvoicePDF();
      // TODO: Implement sharing functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share functionality coming soon!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  String _generateInvoiceContent() {
    final invoice = widget.invoice;
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    final totalAmount = items.fold<double>(0, (sum, item) => sum + (item.quantity * item.rate));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final discount = invoice['discount'] ?? 0.0;
    final finalAmount = totalAmount + vatAmount - discount;

    StringBuffer content = StringBuffer();
    content.writeln('INVOICE');
    content.writeln('Invoice #: ${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}');
    content.writeln('Date: ${invoice['date']}');
    content.writeln('Customer: ${invoice['customer']}');
    content.writeln('Salesman: ${invoice['salesman']}');
    content.writeln('');
    content.writeln('ITEMS:');
    content.writeln('Sr\tDescription\tQty\tRate (SAR)\tVAT (SAR)\tTotal (SAR)');
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemTotal = item.quantity * item.rate;
      final itemVat = itemTotal * (invoice['vatPercent'] ?? 15) / 100;
      final itemTotalWithVat = itemTotal + itemVat;
      content.writeln('${i + 1}\t${item.description}\t${item.quantity}\tSAR ${item.rate}\tSAR ${itemVat.toStringAsFixed(2)}\tSAR ${itemTotalWithVat.toStringAsFixed(2)}');
    }
    
    content.writeln('');
    content.writeln('Subtotal: SAR ${totalAmount.toStringAsFixed(2)}');
    content.writeln('VAT (${invoice['vatPercent'] ?? 15}%): SAR ${vatAmount.toStringAsFixed(2)}');
    if (discount > 0) {
      content.writeln('Discount: -SAR ${discount.toStringAsFixed(2)}');
    }
    content.writeln('TOTAL: SAR ${finalAmount.toStringAsFixed(2)}');
    
    // QR Code Data for all invoices
    final qrData = QRService.generateZatcaQRData(invoice);
    content.writeln('');
    content.writeln('QR Code Data: $qrData');
    
    if (invoice['zatca_invoice'] == true) {
      content.writeln('');
      content.writeln('ZATCA Invoice');
      if (invoice['zatca_uuid'] != null) {
        content.writeln('UUID: ${invoice['zatca_uuid']}');
      }
    } else {
      content.writeln('');
      content.writeln('Invoice (Offline)');
    }
    
    return content.toString();
  }

  Future<Uint8List> _generateInvoicePDF() async {
    // TODO: Implement PDF generation
    return Uint8List.fromList([]);
  }

  Future<bool> _checkPrinterConnection() async {
    try {
      final printerStatus = await _supabaseService.getPrinterStatus();
      return printerStatus['is_connected'] ?? false;
    } catch (e) {
      print('Error checking printer connection: $e');
      return false;
    }
  }

  Future<dynamic> _showPrinterSelectionDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Printer'),
        content: Text('No printer connected. Please connect a printer first.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getZatcaStatus(Map<String, dynamic> invoice) {
    final response = invoice['zatca_response'];
    if (response == null) {
      return 'Not verified';
    }
    
    // Parse ZATCA response if it's a JSON string
    Map<String, dynamic> zatcaResponse = {};
    if (response is String) {
      try {
        zatcaResponse = jsonDecode(response);
      } catch (e) {
        print('Error parsing ZATCA response: $e');
        return 'Parse error';
      }
    } else if (response is Map) {
      zatcaResponse = Map<String, dynamic>.from(response);
    }
    
    final complianceStatus = zatcaResponse['compliance_status'];
    if (complianceStatus == null) {
      return 'Unknown status';
    }
    return complianceStatus.toString();
  }
} 