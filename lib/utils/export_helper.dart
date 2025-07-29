import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ExportHelper {
  Future<String> exportToCSV(List<Map<String, dynamic>> invoices, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName.csv');
      
      final csvData = StringBuffer();
      
      // CSV Header
      csvData.writeln('Invoice Number,Customer,Date,Total,Type,Items Count');
      
      // CSV Rows
      for (final invoice in invoices) {
        final invoiceNumber = invoice['no']?.toString() ?? '';
        final customer = invoice['customer']?.toString() ?? '';
        final date = invoice['date']?.toString() ?? '';
        final total = invoice['total']?.toString() ?? '0.00';
        final type = invoice['zatca_invoice'] == true ? 'ZATCA' : 'LOCAL';
        final itemsCount = (invoice['items'] as List?)?.length.toString() ?? '0';
        
        csvData.writeln('$invoiceNumber,$customer,$date,$total,$type,$itemsCount');
      }
      
      await file.writeAsString(csvData.toString());
      return file.path;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  Future<String> exportToPDF(List<Map<String, dynamic>> invoices, String fileName) async {
    try {
      final pdf = pw.Document();
      
      // Add pages for each invoice
      for (final invoice in invoices) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '#${invoice['no']}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Invoice Details
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Customer: ${invoice['customer']}'),
                            pw.Text('Date: ${invoice['date']}'),
                            pw.Text('Type: ${invoice['zatca_invoice'] == true ? 'ZATCA' : 'LOCAL'}'),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Total: SAR ${invoice['total'].toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Items Table
                  if (invoice['items'] != null) ...[
                    pw.Text(
                      'Items:',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    ...(invoice['items'] as List).map((item) => pw.Padding(
                      padding: pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(item['name']?.toString() ?? ''),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(item['quantity']?.toString() ?? ''),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text('SAR ${item['price']?.toStringAsFixed(2) ?? '0.00'}'),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text('SAR ${item['total']?.toStringAsFixed(2) ?? '0.00'}'),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                  
                  // ZATCA Information
                  if (invoice['zatca_invoice'] == true) ...[
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(),
                        color: PdfColors.grey100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ZATCA Information:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (invoice['zatca_uuid'] != null)
                            pw.Text('UUID: ${invoice['zatca_uuid']}'),
                          if (invoice['zatca_qr_code'] != null)
                            pw.Text('QR Code: Available'),
                          pw.Text('Environment: ${invoice['zatca_environment'] ?? 'live'}'),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }
} 