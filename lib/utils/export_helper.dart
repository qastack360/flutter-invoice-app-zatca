import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ExportHelper {
  Future<String> exportToCSV(List<Map<String, dynamic>> invoices, String fileName) async {
    try {
      // Handle different platforms
      Directory directory;
      
      if (kIsWeb) {
        // Web platform - use temporary directory
        throw Exception('CSV export not supported on web. Please use PDF export instead.');
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms
        try {
          directory = await getApplicationDocumentsDirectory();
        } catch (e) {
          // Fallback to temporary directory
          directory = await getTemporaryDirectory();
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop platforms
        try {
          directory = await getApplicationDocumentsDirectory();
        } catch (e) {
          // Fallback to temporary directory
          directory = await getTemporaryDirectory();
        }
      } else {
        // Unknown platform
        directory = await getTemporaryDirectory();
      }
      
      final file = File('${directory.path}/$fileName.csv');
      
      final csvData = StringBuffer();
      
      // CSV Header - Detailed format with items and VAT
      csvData.writeln('Sr No,Invoice Number,Date,Customer,Item Description,Quantity,Rate (SAR),VAT (SAR),Total (SAR),VAT %,Discount,Final Total (SAR),Type');
      
      // CSV Rows - One row per item
      int srNo = 1;
      for (final invoice in invoices) {
        final invoiceNumber = '${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}';
        final customer = invoice['customer']?.toString() ?? '';
        final date = invoice['date']?.toString() ?? '';
        final vatPercent = invoice['vatPercent'] ?? 15;
        final discount = invoice['discount'] ?? 0.0;
        final finalTotal = invoice['total'] ?? 0.0;
        final type = invoice['zatca_invoice'] == true ? 'ZATCA' : 'Local';
        
        // Add one row per item
        if (invoice['items'] != null) {
          for (final item in invoice['items'] as List) {
            final itemTotal = (item['quantity'] ?? 0) * (item['rate'] ?? 0);
            final itemVat = itemTotal * vatPercent / 100;
            final itemTotalWithVat = itemTotal + itemVat;
            
            csvData.writeln('$srNo,$invoiceNumber,$date,$customer,"${item['description']}",${item['quantity']},${item['rate']},${itemVat.toStringAsFixed(2)},${itemTotalWithVat.toStringAsFixed(2)},$vatPercent%,$discount,$finalTotal,$type');
            srNo++;
          }
        }
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
                            pw.Text('Type: ${invoice['zatca_invoice'] == true ? 'ZATCA' : 'Local'}'),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Total: SAR ${(invoice['total'] ?? 0).toStringAsFixed(2)}'),
                            pw.Text('VAT: SAR ${(invoice['vatAmount'] ?? 0).toStringAsFixed(2)}'),
                            if (invoice['zatca_uuid'] != null)
                              pw.Text('ZATCA UUID: ${invoice['zatca_uuid']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Items Table
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      // Header row
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Sr', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('VAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      // Item rows
                      if (invoice['items'] != null)
                        ...(invoice['items'] as List).asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final itemTotal = (item['quantity'] ?? 0) * (item['rate'] ?? 0);
                          final itemVat = itemTotal * (invoice['vatPercent'] ?? 15) / 100;
                          final itemTotalWithVat = itemTotal + itemVat;
                          
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text('${index + 1}'),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(item['description']?.toString() ?? ''),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text('${item['quantity']}'),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text('SAR ${(item['rate'] ?? 0).toStringAsFixed(2)}'),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text('SAR ${itemVat.toStringAsFixed(2)}'),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text('SAR ${itemTotalWithVat.toStringAsFixed(2)}'),
                              ),
                            ],
                          );
                        }).toList(),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Totals
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Subtotal: SAR ${(invoice['subtotal'] ?? 0).toStringAsFixed(2)}'),
                          pw.Text('VAT: SAR ${(invoice['vatAmount'] ?? 0).toStringAsFixed(2)}'),
                          if ((invoice['discount'] ?? 0) > 0)
                            pw.Text('Discount: SAR ${(invoice['discount'] ?? 0).toStringAsFixed(2)}'),
                          pw.Text(
                            'Total: SAR ${(invoice['total'] ?? 0).toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }
      
      // Handle different platforms for saving
      if (kIsWeb) {
        // Web platform - return PDF bytes
        final pdfBytes = await pdf.save();
        return 'data:application/pdf;base64,${base64Encode(pdfBytes)}';
      } else {
        // Mobile/Desktop platforms
        Directory directory;
        
        try {
          directory = await getApplicationDocumentsDirectory();
        } catch (e) {
          directory = await getTemporaryDirectory();
        }
        
        final file = File('${directory.path}/$fileName.pdf');
        final pdfBytes = await pdf.save();
        await file.writeAsBytes(pdfBytes);
        return file.path;
      }
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }
} 