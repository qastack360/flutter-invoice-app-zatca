// image_capture_service.dart
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:typed_data';
// import '../main.dart'; // ✅ Import for navigatorKey - This import is not used here and can be removed if not needed elsewhere.

class ImageCaptureService {
  static Future<Uint8List?> captureWidget(
      Widget widget, {
        double pixelRatio = 2.0,
        double? widgetHeight, // Add this new parameter
      }) async {
    final controller = ScreenshotController();

    // Conditionally wrap the widget in a SizedBox if widgetHeight is provided
    Widget widgetToCapture = widget;
    if (widgetHeight != null) {
      widgetToCapture = SizedBox(
        width: 576, // Maintain the invoice widget's intrinsic width
        height: widgetHeight,
        child: widget,
      );
    }

    return controller.captureFromWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: widgetToCapture, // Use the potentially wrapped widget
        ),
      ),
      pixelRatio: pixelRatio,
    );
  }
}