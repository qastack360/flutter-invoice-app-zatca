import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/company_details.dart';
import '../models/item_data.dart';

class InvoiceHelper {
  static Future<Uint8List> generatePdf({
    required int invoiceNo,
    required String date,
    required String salesman,
    required String customer,
    required String vatNo,
    required List<ItemData> items,
    required double vatPercent,
    required double discount,
    required double cash,
    required CompanyDetails? companyDetails,
    required String qrData,
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
          final subtotal = items.fold<double>(0, (s, i) => s + i.quantity * i.rate);
          final subtotalVat = items.fold<double>(0, (s, i) => s + (i.quantity * i.rate * vatPercent / 100));
          final total = subtotal + subtotalVat - discount;
          final change = cash - total;

          return pw.Container(
            color: PdfColors.grey200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Company header with larger fonts
                if (companyDetails != null) ...[
                  pw.Center(
                    child: pw.Column(
                      children: [
                        if (companyDetails.ownerName1.isNotEmpty)
                          buildText(companyDetails.ownerName1, size: 15.4, bold: true, align: pw.TextAlign.center),
                        if (companyDetails.ownerName2.isNotEmpty)
                          buildText(companyDetails.ownerName2, size: 14, bold: true, align: pw.TextAlign.center),
                        if (companyDetails.otherName.isNotEmpty)
                          buildText(companyDetails.otherName, size: 12.6, align: pw.TextAlign.center),
                        pw.SizedBox(height: 3),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if (companyDetails.phone.isNotEmpty)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            buildText('Phone / هاتف', align: pw.TextAlign.left),
                            buildText(companyDetails.phone, align: pw.TextAlign.right),
                          ],
                        ),
                      if (companyDetails.vatNo.isNotEmpty)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            buildText('VAT / الضريبة', align: pw.TextAlign.left),
                            buildText(companyDetails.vatNo, align: pw.TextAlign.right),
                          ],
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
                  ['Invoice No / رقم الفاتورة', '$invoiceNo'],
                  ['Date / التاريخ', date],
                  ['Sales Man / الموظف', salesman],
                  ['Customer / اسم العميل', customer],
                  if (vatNo.isNotEmpty) ['VAT No / رقم ضريبي', vatNo],
                ], buildText),
                pw.SizedBox(height: 5),

                // Items table with optimized rendering
                _itemsTable(items, fmt, vatPercent, buildText),
                pw.SizedBox(height: 5),

                // Totals
                _totalsTable(subtotal, discount, subtotalVat, total, cash, change, vatPercent, buildText),
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
                pw.Center(
                  child: pw.Container(
                    color: PdfColors.grey200,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: 170, // Optimized QR size
                      height: 170,
                    ),
                  ),
                ),
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
      List<ItemData> items,
      NumberFormat fmt,
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
            color: PdfColors.grey300,
          ),
          children: [
            _cell('No', 'رقم', buildText),
            _cell('Description', 'وصف', buildText),
            _cell('Qty', 'الكمية', buildText),
            _cell('Rate', 'السعر', buildText),
            _cell('VAT', 'الضريبة', buildText),
            _cell('Total', 'المجموع', buildText),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: buildText('${i+1}', size: 11.2, align: pw.TextAlign.center),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: buildText(items[i].description, size: 12, align: pw.TextAlign.center),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: buildText(items[i].quantity.toStringAsFixed(0), size: 11.2, align: pw.TextAlign.center),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: buildText(fmt.format(items[i].rate), size: 11.2, align: pw.TextAlign.center),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: buildText(fmt.format(items[i].quantity * items[i].rate * vatPercent / 100), size: 11.2, align: pw.TextAlign.center),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: buildText(fmt.format(items[i].quantity * items[i].rate), size: 11.2, align: pw.TextAlign.center),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _totalsTable(
      double sub,
      double disc,
      double vatAmt,
      double total,
      double cash,
      double change,
      double vatPct,
      pw.Widget Function(String, {double size, bool bold, pw.TextAlign align}) buildText,
      ) {
    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
      children: [
        _totalRow('Subtotal / الإجمالي الفرعي', '', sub.toStringAsFixed(2), buildText),
        _totalRow('Discount / الخصم ', '', disc.toStringAsFixed(2), buildText),
        _totalRow('VAT ${vatPct.toStringAsFixed(0)}%', 'ضريبة القيمة المضافة', vatAmt.toStringAsFixed(2), buildText),
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
}