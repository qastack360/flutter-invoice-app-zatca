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

  const PreviewInvoiceScreen({
    Key? key,
    required this.imageData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Print Preview")),
      body: imageData == null
          ? const Center(child: Text('Failed to generate preview'))
          : SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 5.0,
          child: Image.memory(
            imageData!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}