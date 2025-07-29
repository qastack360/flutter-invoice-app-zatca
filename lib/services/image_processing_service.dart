import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessingService {
  static Uint8List processForThermalPrint(Uint8List input) {
    try {
      final image = img.decodeImage(input);
      if (image == null) return input;

      // Create output image with same dimensions
      final output = img.Image(width: image.width, height: image.height);

      // Simple thresholding to preserve QR code
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // Calculate luminance (perceived brightness)
          final luminance = (r * 0.299 + g * 0.587 + b * 0.114).toInt();

          // Preserve very dark pixels (QR code) as black
          if (luminance < 50) {
            output.setPixel(x, y, img.ColorInt8.rgb(0, 0, 0));
          }
          // Convert other pixels to grayscale
          else {
            output.setPixel(x, y, img.ColorInt8.rgb(luminance, luminance, luminance));
          }
        }
      }

      // Resize to thermal printer width (576 pixels is standard)
      final resized = img.copyResize(output, width: 576);

      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      print("Image processing error: $e");
      return input;
    }
  }
}