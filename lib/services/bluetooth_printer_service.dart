import 'dart:typed_data';
import 'dart:ui' as ui; // Added for ImageByteFormat
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;// Added
import 'package:my_invoice_app/services/qr_service.dart';
import 'package:my_invoice_app/widgets/invoice_widget.dart';
import 'package:my_invoice_app/models/item_data.dart';
import 'package:my_invoice_app/models/company_details.dart';
import 'package:my_invoice_app/utils/invoice_helper.dart'; // Added
import 'package:my_invoice_app/services/image_processing_service.dart';
import 'package:pdfx/pdfx.dart' as pdfx;



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

  // FIXED: Print invoice method
  Future<void> printInvoice({
    required int invoiceNo, // Changed to int
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
    await _initMockPrinting();
    if (_mockPrint) {
      print("MOCK PRINTING: Invoice");
      return;
    }

    if (_connectedPrinter == null || _printCharacteristic == null) {
      throw Exception("Printer not connected");
    }

    // Generate PDF
    final pdfBytes = await InvoiceHelper.generatePdf(
      invoiceNo: invoiceNo,
      date: date,
      salesman: salesman,
      customer: customer,
      vatNo: vatNo,
      items: items,
      vatPercent: vatPercent,
      discount: discount,
      cash: cash,
      companyDetails: companyDetails,
      qrData: qrData,
    );

    // Convert PDF to image - FIXED
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
  }
}