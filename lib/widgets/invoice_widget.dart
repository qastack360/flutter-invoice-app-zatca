import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/company_details.dart';
import '../models/item_data.dart';
import 'dart:ui' as ui;

class InvoiceWidget extends StatelessWidget {
  final int invoiceNo;
  final String date;
  final String salesman;
  final String customer;
  final String vatNo;
  final List<ItemData> items;
  final double vatPercent;
  final double discount;
  final double cash;
  final CompanyDetails? companyDetails;
  final Uint8List? qrImageData;

  InvoiceWidget({
    Key? key,
    required this.invoiceNo,
    required this.date,
    required this.salesman,
    required this.customer,
    required this.vatNo,
    required this.items,
    required this.vatPercent,
    required this.discount,
    required this.cash,
    this.companyDetails,
    this.qrImageData,
  }) : super(key: key) {
    print('InvoiceWidget created. qrImageData length: ${qrImageData?.length}');
  }

  @override
  Widget build(BuildContext context) {
    print('InvoiceWidget build called. qrImageData length: ${qrImageData?.length}');
    final subtotal = items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
    final vatAmount = subtotal * vatPercent / 100;
    final total = subtotal + vatAmount - discount;
    final change = cash - total;

    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Container(
          width: 576,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min, // 👈 Important
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Header - Centered
              if (companyDetails != null) ...[
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (companyDetails!.ownerName1.isNotEmpty)
                        Text(
                          companyDetails!.ownerName1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoNaskhArabic',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (companyDetails!.ownerName2.isNotEmpty)
                        Text(
                          companyDetails!.ownerName2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 4),
                      if (companyDetails!.phone.isNotEmpty)
                        Text(
                          'Phone: ${companyDetails!.phone}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      if (companyDetails!.vatNo.isNotEmpty)
                        Text(
                          'VAT: ${companyDetails!.vatNo}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],

              // Invoice Details
              const Divider(thickness: 2, color: Colors.black),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Bill No / رقم الفاتورة",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    "$invoiceNo",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Date / التاريخ", style: TextStyle(fontSize: 12)),
                  Text(date, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Sales Man / الموظف", style: TextStyle(fontSize: 1)),
                  Text(salesman, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Customer / العميل", style: TextStyle(fontSize: 12)),
                  Text(customer, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 1, color: Colors.black),

              // Table Header
              const Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text("No\nرقم", textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text("Description\nالوصف", textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text("Qty\nالكمية", textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text("Rate\nالسعر", textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text("VAT\nالضريبة", textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text("Total\nالمجموع", textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const Divider(thickness: 1, color: Colors.black),

              // Items List
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text("${i+1}", textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          items[i].description,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text("${items[i].quantity}", textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(items[i].rate.toStringAsFixed(2), textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          (items[i].quantity * items[i].rate * vatPercent / 100).toStringAsFixed(2),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          (items[i].quantity * items[i].rate).toStringAsFixed(2),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(thickness: 1, color: Colors.black),
              const SizedBox(height: 6),

              // Totals Section
              _buildTotalRow("Subtotal", "المجموع الفرعي", subtotal),
              _buildTotalRow("Discount", "خصم", discount),
              _buildTotalRow("VAT ${vatPercent.toStringAsFixed(0)}%", "ضريبة", vatAmount),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total / الإجمالي",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    total.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTotalRow("Cash / نقدي", "المبلغ المدفوع", cash),
              _buildTotalRow("Change / الباقي", "المتبقي", change),
              const SizedBox(height: 12),

              // QR Code - Ensure it's always shown
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Text(
                        "Thank you for shopping with us",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "شكرا للتسوق معنا",
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // QR Code with error handling
                      if (qrImageData != null)
                        FutureBuilder<ui.Image>(
                          future: decodeImageFromList(qrImageData!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                              return Container(
                                width: 180,
                                height: 180,
                                color: Colors.white,
                                child: RawImage(
                                  image: snapshot.data!,
                                  fit: BoxFit.contain,
                                ),
                              );
                            } else if (snapshot.hasError) {
                              return const Icon(Icons.error, size: 50, color: Colors.red);
                            } else {
                              return const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            }
                          },
                        )
                      else
                        const CircularProgressIndicator(),


                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String english, String arabic, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ✅ This allows flexible height
              children: [
                Text(english, style: const TextStyle(fontSize: 12)),
                Text(
                  arabic,
                  style: const TextStyle(fontFamily: 'NotoNaskhArabic', fontSize: 12),
                ),
              ],
            ),
          ),
          Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}