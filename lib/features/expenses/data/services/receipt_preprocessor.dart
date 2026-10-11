import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

class ProcessedReceiptImage {
  const ProcessedReceiptImage({
    required this.bytes,
    this.tempFilePath,
    required this.pageIndex,
  });

  final Uint8List bytes;
  final String? tempFilePath;
  final int pageIndex;
}

class ReceiptPreprocessor {
  static const Set<String> supportedExtensions = {'jpg', 'jpeg', 'png', 'pdf'};

  /// Validate if file extension is supported
  static bool isSupportedFormat(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Check if file is a PDF
  static bool isPdf(String fileName) {
    return fileName.split('.').last.toLowerCase() == 'pdf';
  }

  /// Preprocess image bytes (EXIF orientation fix, resize, contrast boost)
  static Uint8List preprocessImageBytes(Uint8List rawBytes) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      // 1. Bake EXIF orientation
      var oriented = img.bakeOrientation(decoded);

      // 2. Resize if too large (max dimension 1800 for optimal OCR speed & accuracy)
      const maxDimension = 1800;
      if (oriented.width > maxDimension || oriented.height > maxDimension) {
        if (oriented.width > oriented.height) {
          oriented = img.copyResize(oriented, width: maxDimension);
        } else {
          oriented = img.copyResize(oriented, height: maxDimension);
        }
      }

      // 3. Contrast adjustment for text enhancement
      final enhanced = img.adjustColor(oriented, contrast: 1.25);

      return Uint8List.fromList(img.encodeJpg(enhanced, quality: 85));
    } catch (e) {
      debugPrint('Image preprocessing notice: $e');
      return rawBytes;
    }
  }

  /// Convert PDF pages into preprocessed image bytes
  static Future<List<Uint8List>> renderPdfPages(String filePath, {int maxPages = 5}) async {
    final result = <Uint8List>[];
    try {
      final document = await PdfDocument.openFile(filePath);
      final count = document.pagesCount > maxPages ? maxPages : document.pagesCount;

      for (int i = 1; i <= count; i++) {
        final page = await document.getPage(i);
        final rendered = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (rendered != null && rendered.bytes.isNotEmpty) {
          final preprocessed = preprocessImageBytes(rendered.bytes);
          result.add(preprocessed);
        }
      }
      await document.close();
    } catch (e) {
      debugPrint('PDF rendering error: $e');
    }
    return result;
  }
}
