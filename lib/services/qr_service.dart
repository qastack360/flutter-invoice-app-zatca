import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/item_data.dart';

class QRService {
  /// Generate ZATCA-compliant QR code data for all invoices
  static String generateZatcaQRData(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List<dynamic>)
        .map((item) => ItemData.fromMap(item as Map<String, dynamic>))
        .toList();
    
    // Calculate totals
    final totalAmount = items.fold<double>(0, (sum, item) => sum + (item.quantity * item.rate));
    final vatAmount = totalAmount * (invoice['vatPercent'] ?? 15) / 100;
    final finalAmount = totalAmount + vatAmount;

    // ZATCA Required QR Code Format - Only mandatory fields
    final qrData = {
      // Required Seller Information (Company)
      'seller_name': invoice['company_name'] ?? 'Company Name',
      'seller_vat_number': invoice['company_vat'] ?? '',
      'seller_cr_number': invoice['company_cr'] ?? '',
      'seller_address': invoice['company_address'] ?? '',
      'seller_city': invoice['company_city'] ?? '',
      'seller_phone': invoice['company_phone'] ?? '',
      'seller_email': invoice['company_email'] ?? '',
      
      // Required Buyer Information (Customer)
      'buyer_name': invoice['customer'] ?? '',
      'buyer_vat_number': invoice['customerVat'] ?? '',
      
      // Required Invoice Information
      'invoice_number': '${invoice['invoice_prefix'] ?? 'INV'}-${invoice['no']}',
      'invoice_date': invoice['date'] ?? '',
      'invoice_time': invoice['time'] ?? DateTime.now().toString().substring(11, 19),
      'invoice_type': invoice['zatca_invoice'] == true ? 'ZATCA' : 'INV_NO',
      'invoice_environment': invoice['zatca_environment'] ?? 'local',
      
      // Required Financial Information
      'subtotal_amount': totalAmount.toStringAsFixed(2),
      'vat_amount': vatAmount.toStringAsFixed(2),
      'total_amount': finalAmount.toStringAsFixed(2),
      'vat_percentage': '${invoice['vatPercent'] ?? 15}%',
      'discount_amount': (invoice['discount'] ?? 0.0).toStringAsFixed(2),
      'cash_received': (invoice['cash'] ?? 0.0).toStringAsFixed(2),
      'change_amount': ((invoice['cash'] ?? 0.0) - finalAmount).toStringAsFixed(2),
      
      // Required ZATCA Information
      'zatca_uuid': invoice['zatca_uuid'] ?? '',
      'sync_status': invoice['sync_status'] ?? 'local',
      
      // Required Items Summary
      'items_count': items.length.toString(),
      'items_summary': items.map((item) => {
        'description': item.description,
        'quantity': item.quantity,
        'rate': item.rate,
        'total': (item.quantity * item.rate).toStringAsFixed(2),
        'vat': ((item.quantity * item.rate) * (invoice['vatPercent'] ?? 15) / 100).toStringAsFixed(2),
      }).toList(),
      
      // Required Timestamp
      'timestamp': DateTime.now().toIso8601String(),
      'qr_version': '1.0',
      'qr_standard': 'ZATCA_COMPLIANT',
    };

    return jsonEncode(qrData);
  }

  /// Generate QR code image from data
  static Future<Uint8List?> generateQRImage(String data) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );

      final qrImage = await qrPainter.toImage(2048.0);
      final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error generating QR code: $e');
      return null;
    }
  }

  // Generate simplified QR code data for ZATCA app (fast scanning)
  static Map<String, dynamic> generateSimplifiedZatcaQRData(Map<String, dynamic> invoiceData) {
    // Calculate totals from items if not provided
    final items = invoiceData['items'] ?? [];
    double total = 0.0;
    
    for (var item in items) {
      double quantity = (item['quantity'] ?? 0).toDouble();
      double rate = (item['rate'] ?? 0).toDouble();
      double vatPercent = (item['vatPercent'] ?? 15.0).toDouble();
      double discount = (item['discount'] ?? 0).toDouble();
      
      double itemTotal = quantity * rate;
      double itemVat = itemTotal * (vatPercent / 100);
      double itemFinal = itemTotal + itemVat - discount;
      
      total += itemFinal;
    }
    
    // Use provided total if available
    total = (invoiceData['total'] ?? invoiceData['finalAmount'] ?? total).toDouble();
    
    // Parse ZATCA response if it's a JSON string
    Map<String, dynamic> zatcaResponse = {};
    if (invoiceData['zatca_response'] != null) {
      if (invoiceData['zatca_response'] is String) {
        try {
          zatcaResponse = jsonDecode(invoiceData['zatca_response']);
        } catch (e) {
          print('Error parsing ZATCA response: $e');
        }
      } else if (invoiceData['zatca_response'] is Map) {
        zatcaResponse = Map<String, dynamic>.from(invoiceData['zatca_response']);
      }
    }
    
    // Only essential data for ZATCA mobile app
    return {
      'uuid': invoiceData['zatca_uuid'] ?? '',
      'invoice_number': '${invoiceData['invoice_prefix'] ?? 'INV'}-${invoiceData['no']}',
      'total': total.toStringAsFixed(2),
      'date': invoiceData['date'] ?? DateTime.now().toString().substring(0, 10),
      'status': (zatcaResponse['compliance_status'] ?? 'verified').toString(),
      'type': 'ZATCA',
    };
  }

  // Generate QR data for printing (includes ZATCA UUID if available)
  static Map<String, dynamic> generatePrintQRData(Map<String, dynamic> invoiceData) {
    // Ensure all required fields for ZATCA mobile app compatibility
    final companyDetails = invoiceData['company'] ?? {};
    final items = invoiceData['items'] ?? [];
    
    // Calculate totals from items if not provided
    double subtotal = 0.0;
    double vatAmount = 0.0;
    double total = 0.0;
    
    for (var item in items) {
      double quantity = (item['quantity'] ?? 0).toDouble();
      double rate = (item['rate'] ?? 0).toDouble();
      double vatPercent = (item['vatPercent'] ?? 15.0).toDouble();
      double discount = (item['discount'] ?? 0).toDouble();
      
      double itemTotal = quantity * rate;
      double itemVat = itemTotal * (vatPercent / 100);
      double itemFinal = itemTotal + itemVat - discount;
      
      subtotal += itemTotal;
      vatAmount += itemVat;
      total += itemFinal;
    }
    
    // Use provided totals if available
    total = (invoiceData['total'] ?? invoiceData['finalAmount'] ?? total).toDouble();
    vatAmount = (invoiceData['vatAmount'] ?? vatAmount).toDouble();
    
    // Parse ZATCA response if it's a JSON string
    Map<String, dynamic> zatcaResponse = {};
    if (invoiceData['zatca_response'] != null) {
      if (invoiceData['zatca_response'] is String) {
        try {
          zatcaResponse = jsonDecode(invoiceData['zatca_response']);
        } catch (e) {
          print('Error parsing ZATCA response: $e');
        }
      } else if (invoiceData['zatca_response'] is Map) {
        zatcaResponse = Map<String, dynamic>.from(invoiceData['zatca_response']);
      }
    }
    
    return {
      'invoice_number': '${invoiceData['invoice_prefix'] ?? 'INV'}-${invoiceData['no']}',
      'date': invoiceData['date'] ?? DateTime.now().toString(),
      'time': DateTime.now().toIso8601String(),
      'total': total.toStringAsFixed(2),
      'vat_amount': vatAmount.toStringAsFixed(2),
      'subtotal': subtotal.toStringAsFixed(2),
      'currency': 'SAR',
      'seller_name': companyDetails['ownerName1'] ?? 'Company Name',
      'seller_vat': companyDetails['vatNo'] ?? '000000000000000',
      'seller_cr': companyDetails['crNumber'] ?? '',
      'seller_address': companyDetails['address'] ?? '',
      'seller_city': companyDetails['city'] ?? '',
      'seller_phone': companyDetails['phone'] ?? '',
      'seller_email': companyDetails['email'] ?? '',
      'customer_name': invoiceData['customer'] ?? 'Walk-In Customer',
      'customer_vat': invoiceData['customerVat'] ?? '',
      'vat_percent': (invoiceData['vatPercent'] ?? 15.0).toString(),
      'discount': (invoiceData['discount'] ?? 0.0).toString(),
      'payment_method': invoiceData['paymentMethod'] ?? 'Cash',
      'invoice_type': invoiceData['zatca_invoice'] == true ? 'ZATCA' : 'INV_NO',
      'environment': invoiceData['zatca_environment'] ?? 'local',
      'zatca_uuid': invoiceData['zatca_uuid'] ?? '',
      'zatca_verified': invoiceData['zatca_verified'] ?? false,
      'verification_url': invoiceData['zatca_uuid'] != null 
          ? 'https://zatca.gov.sa/verify/${invoiceData['zatca_uuid']}'
          : '',
      'qr_scan_message': invoiceData['zatca_uuid'] != null 
          ? 'Scan with ZATCA app to verify this invoice'
          : 'Local invoice - not verified by ZATCA',
      'compliance_status': (zatcaResponse['compliance_status'] ?? '').toString(),
      'reporting_status': (zatcaResponse['reporting_status'] ?? '').toString(),
      'clearance_status': (zatcaResponse['clearance_status'] ?? '').toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
      'format': 'ZATCA_COMPLIANT'
    };
  }

  // Generate QR code image with ZATCA UUID
  static Future<Uint8List> generateQRImageWithUUID(Map<String, dynamic> qrData) async {
    try {
      final qrString = jsonEncode(qrData);
      final qrPainter = QrPainter(
        data: qrString,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: Colors.black,
        emptyColor: Colors.white,
        gapless: false,
      );
      
      final imageData = await qrPainter.toImageData(2048);
      return imageData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate QR code: $e');
    }
  }

  // Generate ZATCA mobile app optimized QR code
  static Map<String, dynamic> generateZatcaMobileQRData(Map<String, dynamic> invoiceData) {
    final companyDetails = invoiceData['company'] ?? {};
    final items = invoiceData['items'] ?? [];
    
    // Calculate totals
    double subtotal = 0.0;
    double vatAmount = 0.0;
    double total = 0.0;
    
    for (var item in items) {
      double quantity = (item['quantity'] ?? 0).toDouble();
      double rate = (item['rate'] ?? 0).toDouble();
      double vatPercent = (item['vatPercent'] ?? 15.0).toDouble();
      double discount = (item['discount'] ?? 0).toDouble();
      
      double itemTotal = quantity * rate;
      double itemVat = itemTotal * (vatPercent / 100);
      double itemFinal = itemTotal + itemVat - discount;
      
      subtotal += itemTotal;
      vatAmount += itemVat;
      total += itemFinal;
    }
    
    total = (invoiceData['total'] ?? invoiceData['finalAmount'] ?? total).toDouble();
    vatAmount = (invoiceData['vatAmount'] ?? vatAmount).toDouble();
    
    // Parse ZATCA response if it's a JSON string
    Map<String, dynamic> zatcaResponse = {};
    if (invoiceData['zatca_response'] != null) {
      if (invoiceData['zatca_response'] is String) {
        try {
          zatcaResponse = jsonDecode(invoiceData['zatca_response']);
        } catch (e) {
          print('Error parsing ZATCA response: $e');
        }
      } else if (invoiceData['zatca_response'] is Map) {
        zatcaResponse = Map<String, dynamic>.from(invoiceData['zatca_response']);
      }
    }
    
    // ZATCA mobile app optimized format
    return {
      // Core invoice data
      'id': invoiceData['zatca_uuid'] ?? '',
      'invoice_number': '${invoiceData['invoice_prefix'] ?? 'INV'}-${invoiceData['no']}',
      'date': invoiceData['date'] ?? DateTime.now().toString(),
      'total': total.toStringAsFixed(2),
      'vat_amount': vatAmount.toStringAsFixed(2),
      'currency': 'SAR',
      
      // Seller information (required for ZATCA verification)
      'seller': {
        'name': companyDetails['ownerName1'] ?? 'Company Name',
        'vat_number': companyDetails['vatNo'] ?? '000000000000000',
        'cr_number': companyDetails['crNumber'] ?? '',
        'address': companyDetails['address'] ?? '',
        'city': companyDetails['city'] ?? '',
        'phone': companyDetails['phone'] ?? '',
        'email': companyDetails['email'] ?? ''
      },
      
      // Customer information
      'customer': {
        'name': invoiceData['customer'] ?? 'Walk-In Customer',
        'vat_number': invoiceData['customerVat'] ?? ''
      },
      
      // ZATCA specific data
      'zatca': {
        'uuid': invoiceData['zatca_uuid'] ?? '',
        'verified': invoiceData['zatca_verified'] ?? false,
        'compliance_status': (zatcaResponse['compliance_status'] ?? '').toString(),
        'reporting_status': (zatcaResponse['reporting_status'] ?? '').toString(),
        'clearance_status': (zatcaResponse['clearance_status'] ?? '').toString(),
        'environment': invoiceData['zatca_environment'] ?? 'local',
        'verification_url': invoiceData['zatca_uuid'] != null 
            ? 'https://zatca.gov.sa/verify/${invoiceData['zatca_uuid']}'
            : ''
      },
      
      // Metadata
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
      'format': 'ZATCA_MOBILE_APP'
    };
  }

  // Generate verification message for QR code
  static String generateVerificationMessage(Map<String, dynamic> qrData) {
    final uuid = qrData['zatca_uuid'] ?? qrData['id'] ?? '';
    final verified = qrData['zatca_verified'] ?? false;
    final invoiceNumber = qrData['invoice_number'] ?? '';
    final total = qrData['total'] ?? '';
    
    if (uuid.isNotEmpty && verified) {
      return '''
✅ ZATCA VERIFIED INVOICE
Invoice: $invoiceNumber
Total: SAR $total
UUID: $uuid
Scan with ZATCA app to verify
''';
    } else if (uuid.isNotEmpty) {
      return '''
⚠️ ZATCA PENDING VERIFICATION
Invoice: $invoiceNumber
Total: SAR $total
UUID: $uuid
Contact seller for verification
''';
    } else {
      return '''
📄 LOCAL INVOICE
Invoice: $invoiceNumber
Total: SAR $total
Not verified by ZATCA
''';
    }
  }
}