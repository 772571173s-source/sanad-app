import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportExportService {
  /// Sanitize filename: remove chars not allowed in file systems.
  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  /// Build a clean PDF file name from student / program info.
  static String buildFileName({
    required String studentName,
    String? programName,
  }) {
    final clean = sanitizeFileName(studentName);
    final prog = programName != null ? '_${sanitizeFileName(programName)}' : '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'sanad_report_$clean${prog}_$ts.pdf';
  }

  /// Export a PDF smart report according to the running platform.
  ///
  /// Returns the file path of the saved / shared file, or `null` if the user
  /// cancels (Windows save dialog) or if the platform is unsupported (web).
  ///
  /// - **Desktop** (Windows, Linux, macOS): Opens a native "Save File" dialog
  ///   via [FilePicker]. The caller writes bytes and saves the [ReportRecord].
  /// - **Mobile** (Android, iOS): Saves the PDF to the app documents directory,
  ///   then opens the system share sheet via [Share.shareXFiles]. The temp path
  ///   is returned so the caller can store it in [ReportRecord.filePath].
  /// - **Web**: Returns `null` (TODO).
  static Future<String?> exportPdf({
    required List<int> pdfBytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      // TODO: web export support
      return null;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return _exportMobile(pdfBytes, fileName);
    }

    return _exportDesktop(pdfBytes, fileName);
  }

  // ---------------------------------------------------------------------------
  // Desktop – FilePicker save
  // ---------------------------------------------------------------------------
  static Future<String?> _exportDesktop(
    List<int> pdfBytes,
    String fileName,
  ) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ تقرير PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputPath == null) return null;

    await File(outputPath).writeAsBytes(pdfBytes);
    final saved = File(outputPath);
    if (!saved.existsSync() || saved.lengthSync() == 0) {
      throw Exception('فشل حفظ الملف على القرص.');
    }
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // Mobile – Share sheet
  // ---------------------------------------------------------------------------
  static Future<String?> _exportMobile(
    List<int> pdfBytes,
    String fileName,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }
    final filePath = '${reportsDir.path}/$fileName';
    await File(filePath).writeAsBytes(pdfBytes);

    final saved = File(filePath);
    if (!saved.existsSync() || saved.lengthSync() == 0) {
      throw Exception('فشل حفظ الملف المؤقت للمشاركة.');
    }

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'تقرير سند',
    );

    return filePath;
  }
}
