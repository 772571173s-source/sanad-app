import 'dart:io';

import 'package:docx_creator/docx_creator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/word_report_model.dart';

class WordReportServiceV2 {
  static Future<List<int>> generateBytes(WordReportModel model) async {
    final doc = await _buildDocument(model);
    final exporter = DocxExporter();
    final bytes = await exporter.exportToBytes(doc);
    return bytes;
  }

  static Future<String?> generate({
    required WordReportModel model,
  }) async {
    final bytes = await generateBytes(model);

    if (kIsWeb) return null;

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'sanad_report_v2_${_sanitize(model.studentName)}_$ts.docx';
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
    final bytes = await generateBytes(model);

    if (kIsWeb) return null;

    if (!Platform.isAndroid && !Platform.isIOS) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير Word V2 تجريبي',
        fileName: 'sanad_center_quarterly_v2_poc.docx',
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
    final filePath =
        '${reportsDir.path}/sanad_center_quarterly_v2_poc.docx';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles(
        [XFile(filePath)], text: 'تقرير Word V2 تجريبي - سند');
    return filePath;
  }

  static Future<DocxBuiltDocument> _buildDocument(
      WordReportModel model) async {
    final builder = docx()
      .section(
        orientation: DocxPageOrientation.landscape,
        pageSize: DocxPageSize.a4,
        marginTop: 720,
        marginBottom: 720,
        marginLeft: 720,
        marginRight: 720,
      )
      .paragraph(DocxParagraph.heading1(
        'التقرير الربع سنوي للحالة',
        align: DocxAlign.right,
      ))
      .p(model.dateRange, align: DocxAlign.right)
      .p('${model.centerName} | ${model.studentName}',
          align: DocxAlign.right)
      .p('')
      .p('الدرجة 2 = يستطيع أداء المهارة باستقلالية',
          align: DocxAlign.right)
      .p('الدرجة 1 = يستطيع أداء المهارة جزئيًا أو بمساعدة',
          align: DocxAlign.right)
      .p('الدرجة 0 = لا يستطيع أداء المهارة نهائيًا',
          align: DocxAlign.right);

    for (final section in model.sections) {
      builder.p('');
      builder.paragraph(DocxParagraph.heading2(
        section.sectionTitle,
        align: DocxAlign.right,
      ));

      if (section.rows.length > 1) {
        final columnCount = section.rows.first.cells.length;
        final gridCols = _gridColumns(columnCount);

        final headerCells = section.rows.first.cells.map((cell) {
          return DocxTableCell.text(
            cell,
            isBold: true,
            align: DocxAlign.right,
            verticalAlign: DocxVerticalAlign.center,
            shadingFill: 'E0F2FE',
          );
        }).toList();

        final dataRows = section.rows.skip(1).map((row) {
          return DocxTableRow(
            cells: row.cells.map((cell) {
              return DocxTableCell.text(
                cell,
                align: DocxAlign.right,
                verticalAlign: DocxVerticalAlign.center,
              );
            }).toList(),
          );
        }).toList();

        builder.addTable(DocxTable(
          rows: [DocxTableRow(cells: headerCells), ...dataRows],
          style: DocxTableStyle(
            border: DocxBorder.single,
            borderColor: '4472C4',
            borderWidth: 4,
            headerFill: 'E0F2FE',
          ),
          width: 5000,
          widthType: DocxWidthType.pct,
          gridColumns: gridCols,
          hasHeader: true,
          alignment: DocxAlign.right,
        ));
      } else if (section.rows.length == 1) {
        final singleCell = section.rows.first.cells;
        builder.p(
          singleCell.isNotEmpty ? singleCell.first : '',
          align: DocxAlign.right,
        );
      }
    }

    return builder.build();
  }

  static List<int>? _gridColumns(int count) {
    switch (count) {
      case 7:
        return [1800, 1800, 5200, 900, 900, 900, 2200];
      case 5:
        return [2000, 2000, 4800, 1400, 3000];
      case 4:
        return [3000, 3000, 5000, 3400];
      case 3:
        return [3800, 6000, 4200];
      case 1:
        return [14000];
      default:
        return null;
    }
  }

  static WordReportModel _testModel() {
    return WordReportModel(
      centerName: 'مركز سند التجريبي',
      studentName: 'طالب تجريبي',
      dateRange: 'الربع الأول - 2026',
      sections: [
        WordReportSection(
          sectionTitle: 'بيانات الجلسات',
          rows: [
            WordReportRow(cells: [
              'نوع الخدمة',
              'مجال المهارة',
              'الأهداف الفصلية / المهارات التعليمية والتدريبية',
              '1',
              '2',
              '3',
              'مقدم الخدمة',
            ]),
            WordReportRow(cells: [
              'العلاج النطقي',
              'المهارات اللغوية',
              'أن ينطق الطفل الكلمات بوضوح',
              '0',
              '1',
              '2',
              'أخصائي نطق',
            ]),
            WordReportRow(cells: [
              'العلاج الوظيفي',
              'المهارات الدقيقة',
              'أن يتقن الطالب المهارات الدقيقة',
              '1',
              '1',
              '2',
              'أخصائي وظيفي',
            ]),
            WordReportRow(cells: [
              'البرنامج التربوي',
              'الرياضيات',
              'أن يكتب الطالب الأعداد من 1 إلى 10',
              '',
              '1',
              '1',
              'معلم تربوي',
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
