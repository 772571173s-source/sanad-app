import 'dart:io';

import 'package:docs_gee/docs_gee.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/word_report_model.dart';

class WordReportService {
  static List<int> generateBytes(WordReportModel model) {
    final doc = _buildDocument(model);
    return DocxGenerator().generate(doc);
  }

  static Future<String?> generate({
    required WordReportModel model,
  }) async {
    final bytes = generateBytes(model);

    if (kIsWeb) return null;

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'sanad_report_${_sanitize(model.studentName)}_$ts.docx';
    final filePath = '${reportsDir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);

    final saved = File(filePath);
    if (!saved.existsSync() || saved.lengthSync() == 0) {
      throw Exception('فشل حفظ ملف Word.');
    }

    await Share.shareXFiles([XFile(filePath)], text: 'تقرير سند');

    return filePath;
  }

  static Future<String?> generateTestDocx() async {
    final model = _testModel();
    final bytes = generateBytes(model);

    if (kIsWeb) return null;

    if (!Platform.isAndroid && !Platform.isIOS) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير Word تجريبي',
        fileName: 'sanad_test_report.docx',
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
      if (outputPath == null) return null;
      await File(outputPath).writeAsBytes(bytes);
      return outputPath;
    }

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }
    final filePath = '${reportsDir.path}/sanad_test_report.docx';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], text: 'تقرير Word تجريبي - سند');
    return filePath;
  }

  static Document _buildDocument(WordReportModel model) {
    final doc = Document(
      title: 'تقرير سند',
      author: 'منصة سند',
    );

    doc.addParagraph(Paragraph.text(
      'تقرير سند',
      alignment: DocxAlignment.right,
    ));

    doc.addParagraph(Paragraph.text(
      '${model.centerName} | ${model.studentName}',
      alignment: DocxAlignment.right,
    ));

    doc.addParagraph(Paragraph.text(
      'الفترة: ${model.dateRange}',
      alignment: DocxAlignment.right,
    ));

    for (final section in model.sections) {
      doc.addParagraph(Paragraph.empty());

      doc.addParagraph(Paragraph.heading(
        section.sectionTitle,
        level: 2,
        alignment: DocxAlignment.right,
      ));

      if (section.rows.length > 1) {
        final headerCells = section.rows.first.cells.map((cell) {
          return DocxTableCell(
            paragraphs: [
              DocxParagraph(
                runs: [DocxRun(cell, bold: true)],
                alignment: DocxAlignment.right,
              ),
            ],
            backgroundColor: 'E0F2FE',
          );
        }).toList();

        final dataRows = section.rows.skip(1).map((row) {
          return DocxTableRow(
            cells: row.cells.map((cell) {
              return DocxTableCell.text(cell, alignment: DocxAlignment.right);
            }).toList(),
          );
        }).toList();

        doc.addTable(DocxTable(
          borders: const DocxTableBorders.all(),
          rows: [DocxTableRow(cells: headerCells), ...dataRows],
        ));
      } else if (section.rows.length == 1) {
        final singleCell = section.rows.first.cells;
        doc.addParagraph(Paragraph.text(
          singleCell.isNotEmpty ? singleCell.first : '',
          alignment: DocxAlignment.right,
        ));
      }
    }

    return doc;
  }

  static WordReportModel _testModel() {
    return WordReportModel(
      centerName: 'مركز سند التجريبي',
      studentName: 'طالب تجريبي',
      dateRange: 'التقرير الربع سنوي - الربع الأول - 2026',
      sections: [
        WordReportSection(
          sectionTitle: 'بيانات الجلسات',
          rows: [
            WordReportRow(cells: [
              'نوع الخدمة',
              'مجال المهارة',
              'الهدف',
              '1',
              '2',
              '3',
              'مقدم الخدمة',
            ]),
            WordReportRow(cells: [
              'علاج نطق',
              'مخارج حروف',
              'نطق حرف الراء',
              '0',
              '1',
              '2',
              'أ. أحمد',
            ]),
            WordReportRow(cells: [
              'علاج وظيفي',
              'مهارات حركية',
              'المشي على خط مستقيم',
              '1',
              '2',
              '',
              'أ. سارة',
            ]),
            WordReportRow(cells: [
              'علاج سلوكي',
              'تواصل',
              'طلب المساعدة',
              '0',
              '',
              '',
              'أ. خالد',
            ]),
          ],
        ),
        WordReportSection(
          sectionTitle: 'ملاحظات',
          rows: [
            WordReportRow(cells: [
              'تم تحقيق تقدم ملحوظ في جلسات النطق. يحتاج الطالب إلى مزيد من الدعم في المهارات الحركية.',
            ]),
          ],
        ),
      ],
    );
  }

  static String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
