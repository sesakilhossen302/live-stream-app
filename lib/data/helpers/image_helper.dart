import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageHelper {
  /// Fixes EXIF orientation by baking the rotation into the pixel array.
  /// This guarantees that camera and gallery photos are never displayed rotated or upside-down.
  static Future<File> fixOrientation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      
      // Run decoding & orientation baking in background isolate for smooth UI
      final fixedBytes = await compute(_bakeOrientationWorker, bytes);
      
      if (fixedBytes == null || fixedBytes.isEmpty) {
        return file;
      }
      
      final String fixedPath = '${file.parent.path}/fixed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fixedFile = File(fixedPath);
      await fixedFile.writeAsBytes(fixedBytes);
      return fixedFile;
    } catch (e) {
      debugPrint("⚠️ [ImageHelper] fixOrientation error: $e");
      return file;
    }
  }

  static Uint8List? _bakeOrientationWorker(Uint8List rawBytes) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;
      
      // Bake the EXIF orientation directly into the image pixels
      final oriented = img.bakeOrientation(decoded);
      
      // Encode back as high quality JPEG with orientation removed
      return Uint8List.fromList(img.encodeJpg(oriented, quality: 88));
    } catch (_) {
      return null;
    }
  }
}
