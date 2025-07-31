import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/company_details.dart';
import '../models/item_data.dart';
import 'dart:convert';

class InvoiceHelper {
  static Future<Uint8List> generatePdf({
    required String invoiceNumber,
    required Map<String, dynamic> invoiceData,
    required Map<String, dynamic> qrData,
    required String customerName,
    required String date,
    required List<Map<String, dynamic>> items,
    required double total,
    required double vatAmount,
    required double subtotal,
    required double discount,
    required String vatPercent,
    required Map<String, dynamic> companyDetails,
    String? verificationMessage,
    String? salesman,
    String? cash,
    String? customer,
    String? vatNo,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 2);

    // Load high-quality fonts
    final arabicFont = await loadFont('assets/fonts/Amiri-Regular.ttf');
    final arabicBold = await loadFont('assets/fonts/Amiri-Bold.ttf');
    final latinFont = await loadFont('assets/fonts/NotoSans-Regular.ttf');
    final latinBold = await loadFont('assets/fonts/NotoSans-Bold.ttf');

    bool isArabic(String text) {
      final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
      return arabicRegex.hasMatch(text);
    }

    // Font size increased by 40% for better readability
    pw.Widget buildText(String text, {double size = 11.2, bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
      if (isArabic(text)) {
        return pw.Text(
          text,
          style: pw.TextStyle(
            font: bold ? arabicBold : arabicFont,
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            // Improve text rendering quality
            wordSpacing: 0.5,
            letterSpacing: 0.2,
          ),
          textDirection: pw.TextDirection.rtl,
          textAlign: align,
        );
      }
      return pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? latinBold : latinFont,
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          // Improve text rendering quality
          wordSpacing: 0.5,
          letterSpacing: 0.1,
        ),
        textAlign: align,
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
            marginLeft: 0.2 * PdfPageFormat.mm,
            marginRight: 0.2 * PdfPageFormat.mm,
            marginTop: 0.5 * PdfPageFormat.mm,
            marginBottom: 1.0 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: latinFont,
          bold: latinBold,
        ),
        build: (ctx) {
          // Calculate totals from items
          final subtotal = items.fold<double>(0, (s, i) => s + (i['quantity'] ?? 0) * (i['rate'] ?? 0));
          final subtotalVat = items.fold<double>(0, (s, i) => s + ((i['quantity'] ?? 0) * (i['rate'] ?? 0) * double.parse(vatPercent) / 100));
          final change = (double.tryParse(cash ?? '0') ?? 0) - total;

          return pw.Container(
            color: PdfColors.white, // White background for thermal printer
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Company header with larger fonts
                if (companyDetails != null) ...[
                  pw.Center(
                    child: pw.Column(
                      children: [
                        if ((companyDetails['ownerName1'] ?? '').isNotEmpty)
                          buildText(companyDetails['ownerName1'] ?? '', size: 15.4, bold: true, align: pw.TextAlign.center),
                        if ((companyDetails['ownerName2'] ?? '').isNotEmpty)
                          buildText(companyDetails['ownerName2'] ?? '', size: 14, bold: true, align: pw.TextAlign.center),
                        if ((companyDetails['otherName'] ?? '').isNotEmpty)
                          buildText(companyDetails['otherName'] ?? '', size: 12.6, align: pw.TextAlign.center),
                        pw.SizedBox(height: 3),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if ((companyDetails['phone'] ?? '').isNotEmpty)
                        pw.Container(
                          width: double.infinity,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              buildText('Phone / الهاتف', size: 10),
                              buildText(companyDetails['phone'] ?? '', align: pw.TextAlign.right),
                            ],
                          ),
                        ),
                      if ((companyDetails['vatNo'] ?? '').isNotEmpty)
                        pw.Container(
                          width: double.infinity,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              buildText('VAT No / الرقم الضريبي', size: 10),
                              buildText(companyDetails['vatNo'] ?? '', align: pw.TextAlign.right),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Clear divider
                  pw.Divider(
                      thickness: 1.0,
                      color: PdfColors.black,
                      // Better line rendering
                      borderStyle: pw.BorderStyle.solid
                  ),
                ],

                // Invoice details
                ..._infoRows([
                  ['Invoice No / رقم الفاتورة', invoiceNumber],
                  ['Date / التاريخ', date],
                  ['Sales Man / الموظف', salesman ?? ''],
                  ['Customer / اسم العميل', customer ?? ''],
                  if ((vatNo ?? '').isNotEmpty) ['VAT No / رقم ضريبي', vatNo ?? ''],
                ], buildText),
                
                // ZATCA Verification Status in Header (only for ZATCA invoices)
                if (invoiceData['zatca_invoice'] == true && invoiceData['zatca_uuid'] != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text('✅ ', style: pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                        buildText('ZATCA Verified Invoice', size: 12, bold: true),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ],

                // ZATCA Details Section (only for ZATCA invoices)
                if (invoiceData['zatca_invoice'] == true && invoiceData['zatca_uuid'] != null) ...[
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.black, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        buildText('ZATCA Details:', size: 12, bold: true),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            buildText('UUID:', size: 10, bold: true),
                            buildText(invoiceData['zatca_uuid'] ?? '', size: 10),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            buildText('Status:', size: 10, bold: true),
                            buildText(_getZatcaStatus(invoiceData), size: 10),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ],

                // Items table with optimized rendering
                _itemsTable(items, double.parse(vatPercent), buildText),
                pw.SizedBox(height: 5),

                // Totals
                _totalsTable(subtotal, discount, subtotalVat, total, double.tryParse(cash ?? '0') ?? 0, change, vatPercent, buildText),
                pw.SizedBox(height: 5),

                // Footer
                pw.Center(
                  child: buildText('Total Items: ${items.length}', size: 12.6),
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Column(children: [
                    buildText('Thank you for shopping with us', size: 12.6),
                    buildText('شكرا لتسوقك معنا!', size: 12.6, align: pw.TextAlign.center),
                  ]),
                ),
                pw.SizedBox(height: 5),
                // QR Code (simplified for ZATCA app)
                pw.Center(
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: jsonEncode(qrData),
                      width: 150, // Slightly smaller for faster scanning
                      height: 150,
                    ),
                  ),
                ),
                
                // ZATCA Verification Message (only for ZATCA invoices)
                if (invoiceData['zatca_invoice'] == true && invoiceData['zatca_uuid'] != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: buildText(
                      'This invoice is now verified with ZATCA and can be scanned with the ZATCA mobile app.',
                      size: 10,
                      align: pw.TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<pw.Font> loadFont(String path) async {
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }

  static pw.Widget _detailRow(
      String label,
      String value,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return pw.Row(children: [
      buildText('$label: ', size: 12.6),
      buildText(value, size: 12.6, bold: true),
    ]);
  }

  static List<pw.Widget> _infoRows(
      List<List<String>> rows,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return rows.map((r) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        buildText(r[0], size: 12.6),
        buildText(r[1], size: 12.6, bold: true),
      ],
    )).toList();
  }

  static pw.Widget _itemsTable(
      List<Map<String, dynamic>> items,
      double vatPercent,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return pw.Table(
      // Improved border rendering
      border: pw.TableBorder.all(
          color: PdfColors.black,
          width: 0.8,
          style: pw.BorderStyle.solid
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.7),
        1: const pw.FlexColumnWidth(2.7),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.white,
          ),
          children: [
            buildText('Sr', size: 10, bold: true, align: pw.TextAlign.center),
            buildText('Description', size: 10, bold: true, align: pw.TextAlign.center),
            buildText('Qty', size: 10, bold: true, align: pw.TextAlign.center),
            buildText('Rate', size: 10, bold: true, align: pw.TextAlign.center),
            buildText('VAT', size: 10, bold: true, align: pw.TextAlign.center),
            buildText('Total', size: 10, bold: true, align: pw.TextAlign.center),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              buildText('${index + 1}', size: 10, align: pw.TextAlign.center),
              buildText(item['description'] ?? '', size: 10),
              buildText('${item['quantity'] ?? 0}', size: 10, align: pw.TextAlign.center),
              buildText('${item['rate'] ?? 0}', size: 10, align: pw.TextAlign.center),
              buildText('${((item['quantity'] ?? 0) * (item['rate'] ?? 0) * vatPercent / 100).toStringAsFixed(2)}', size: 10, align: pw.TextAlign.center),
              buildText('${((item['quantity'] ?? 0) * (item['rate'] ?? 0) * (1 + vatPercent / 100)).toStringAsFixed(2)}', size: 10, align: pw.TextAlign.center),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _totalsTable(
      double subtotal,
      double discount,
      double subtotalVat,
      double total,
      double cash,
      double change,
      String vatPercent,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
      children: [
        _totalRow('Subtotal / الإجمالي الفرعي', '', subtotal.toStringAsFixed(2), buildText),
        _totalRow('Discount / الخصم ', '', discount.toStringAsFixed(2), buildText),
        _totalRow('VAT (${double.parse(vatPercent).toStringAsFixed(1)}%): SAR ${subtotalVat.toStringAsFixed(2)}', '', '', buildText),
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildText('Total /  الإجمالي ', size: 14, bold: true),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: buildText(total.toStringAsFixed(2), size: 14, bold: true, align: pw.TextAlign.right),
          ),
        ]),
        _totalRow('Cash / نقدي المبلغ المدفوع ','', cash.toStringAsFixed(2), buildText),
        _totalRow('Change / الباقي المتبقي ','', change.toStringAsFixed(2), buildText),
      ],
    );
  }

  static pw.Widget _cell(
      String english,
      String arabic,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          buildText(english, size: 12.6, bold: true, align: pw.TextAlign.center),
          buildText(arabic, size: 12.6, bold: true, align: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.TableRow _totalRow(
      String englishLabel,
      String arabicLabel,
      String value,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return pw.TableRow(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildText(englishLabel, size: 12.6),
            buildText(arabicLabel, size: 12.6),
          ],
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: buildText(value, size: 12.6, align: pw.TextAlign.right),
      ),
    ]);
  }

  static String _getZatcaStatus(Map<String, dynamic> invoiceData) {
    final response = invoiceData['zatca_response'];
    if (response == null) {
      return 'N/A';
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
      return 'N/A';
    }
    return complianceStatus.toString();
  }
}