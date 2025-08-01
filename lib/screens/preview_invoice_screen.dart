// preview_invoice_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_invoice_app/models/item_data.dart';
import 'package:my_invoice_app/models/company_details.dart';
import 'package:my_invoice_app/services/image_capture_service.dart';
import 'package:my_invoice_app/services/image_processing_service.dart';
import 'package:my_invoice_app/widgets/invoice_widget.dart';
import 'package:my_invoice_app/services/qr_service.dart'; // ✅ Add this

import 'dart:typed_data';
import 'package:flutter/material.dart';

class PreviewInvoiceScreen extends StatelessWidget {
  final Uint8List? imageData;
  final bool isZatcaInvoice; // Add this parameter

  const PreviewInvoiceScreen({
    Key? key,
    required this.imageData,
    this.isZatcaInvoice = false, // Default to false
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isZatcaInvoice ? "ZATCA Invoice Preview" : "Print Preview"),
        backgroundColor: isZatcaInvoice ? Colors.orange : null,
      ),
      body: imageData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Failed to generate preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (isZatcaInvoice) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code, color: Colors.orange[700], size: 32),
                          SizedBox(height: 8),
                          Text(
                            'ZATCA Invoice',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'QR code will be generated after ZATCA verification',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
        scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  if (isZatcaInvoice) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ZATCA Invoice - QR code will be generated after verification',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  InteractiveViewer(
          minScale: 0.1,
          maxScale: 5.0,
          child: Image.memory(
            imageData!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
                  ),
                ],
        ),
      ),
    );
  }
}