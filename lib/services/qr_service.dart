import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRService {
  static Future<Uint8List> generateQRImage(String data) async {
    try {
      final qrImage = await QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        color: const Color(0xFF000000), // Black dots
        emptyColor: const Color(0xFFFFFFFF), // White background (was transparent)
      ).toImage(180);

      final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      final qrImage = await QrPainter(
        data: "ERROR",
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF), // White background for error too
      ).toImage(180);

      final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }
  }
}