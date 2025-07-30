import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:my_invoice_app/models/item_data.dart';
import 'package:my_invoice_app/models/company_details.dart';
import 'package:my_invoice_app/utils/invoice_helper.dart';
import 'package:my_invoice_app/services/image_processing_service.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'dart:convert'; // Added for jsonEncode
import 'package:my_invoice_app/services/qr_service.dart'; // Added for QRService


class BluetoothPrinterService {
  static final BluetoothPrinterService _instance = BluetoothPrinterService
      ._internal();

  factory BluetoothPrinterService() => _instance;

  BluetoothPrinterService._internal();

  BluetoothDevice? _connectedPrinter;
  BluetoothCharacteristic? _printCharacteristic;
  bool _mockPrint = false;

  Future<void> _initMockPrinting() async {
    final prefs = await SharedPreferences.getInstance();
    _mockPrint = prefs.getBool('mockPrinting') ?? false;
  }

  Future<void> setPrinterDevice(BluetoothDevice device) async {
    _connectedPrinter = device;

    // Discover services and find the print characteristic
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          _printCharacteristic = characteristic;
          print("Found print characteristic: ${characteristic.uuid}");
          break;
        }
      }
    }

    if (_printCharacteristic == null) {
      print("Warning: No print characteristic found. Trying fallback...");
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service
            .characteristics) {
          if (characteristic.uuid.toString().toUpperCase() ==
              "0000AE01-0000-1000-8000-00805F9B34FB") {
            _printCharacteristic = characteristic;
            print("Using fallback print characteristic");
            break;
          }
        }
      }
    }

    if (_printCharacteristic == null) {
      throw Exception("No print characteristic found on this device");
    }
  }

  Future<void> printRasterImage(Uint8List imageBytes) async {
    await _initMockPrinting();
    if (_mockPrint) {
      print("MOCK PRINTING: Raster image");
      return;
    }

    if (_connectedPrinter == null || _printCharacteristic == null) {
      throw Exception("Printer not connected");
    }

    // Process image for thermal printing (with QR protection)
    imageBytes = ImageProcessingService.processForThermalPrint(imageBytes);

    // Generate ESC/POS commands for raster image
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];
    bytes += generator.reset();

    // Use the processed image directly
    final image = img.decodeImage(imageBytes)!;

    bytes += generator.imageRaster(
      image,
      highDensityHorizontal: true,
      highDensityVertical: true,
      imageFn: PosImageFn.bitImageRaster,
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    // Send to printer
    const chunkSize = 200;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = i + chunkSize < bytes.length ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);
      await _printCharacteristic!.write(chunk);
    }
  }

  // FIXED: Print invoice method with ZATCA support
  Future<void> printInvoice({
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
  }) async {
    try {
      // Generate ZATCA mobile optimized QR data
      final zatcaQRData = QRService.generateZatcaMobileQRData(invoiceData);
      final verificationMessage = QRService.generateVerificationMessage(zatcaQRData);
      
      // Generate PDF with ZATCA mobile QR
      final pdfBytes = await InvoiceHelper.generatePdf(
        invoiceNumber: invoiceNumber,
        invoiceData: invoiceData,
        qrData: zatcaQRData,
        customerName: customerName,
        date: date,
        items: items,
        total: total,
        vatAmount: vatAmount,
        subtotal: subtotal,
        discount: discount,
        vatPercent: vatPercent,
        companyDetails: companyDetails,
        verificationMessage: verificationMessage,
      );

      // Convert PDF to image
      final doc = await pdfx.PdfDocument.openData(pdfBytes);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: (page.width * 3).toDouble(),
        height: (page.height * 3).toDouble(),
      );
      final imageBytes = pageImage?.bytes;

      await page.close();
      await doc.close();

      if (imageBytes == null) {
        throw Exception("Failed to render PDF to image");
      }

      await printRasterImage(imageBytes);
    } catch (e) {
      print("Error printing invoice: $e");
      rethrow;
    }
  }
}