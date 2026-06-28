import 'dart:convert';
import 'dart:io';

import 'package:docx_creator/docx_creator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/center_report_settings.dart';
import '../models/word_report_model.dart';

class WordReportServiceV2 {
  // =================================================================
  //  PUBLIC API
  // =================================================================

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

  // =================================================================
  //  DOCUMENT BUILDER
  // =================================================================

  static Future<DocxBuiltDocument> _buildDocument(
      WordReportModel model) async {
    final settings = model.centerSettings;

    final builder = docx()
      .section(
        orientation: DocxPageOrientation.portrait,
        pageSize: DocxPageSize.a4,
        marginTop: 400,
        marginBottom: 400,
        marginLeft: 720,
        marginRight: 720,
      );

    _buildOfficialFirstPagePortrait(builder, model, settings);
    builder.pageBreak();
    _buildPortraitEvaluationPage(builder, model);

    return builder.build();
  }

  // =================================================================
  //  PAGE 1 — Official first page (Entirely Portrait)
  // =================================================================

  static void _buildOfficialFirstPagePortrait(
    DocxDocumentBuilder builder,
    WordReportModel model,
    CenterReportSettings? s,
  ) {
    _addCompactHeader(builder, model, s);
    _addCompactCaseTable(builder, model, s);
    _addCompactRediagnosisTable(builder, model);
    _addCompactServicesTable(builder, model);
    _addCompactEvalRecTable(builder, model, s);
  }

  /// 3-column header: english (left) | logo (center) | arabic (right).
  /// No border, first element on page, no preceding paragraphs.
  static void _addCompactHeader(
    DocxDocumentBuilder builder,
    WordReportModel model,
    CenterReportSettings? s,
  ) {
    if (s == null) return;
    final arabic = s.arabicHeaderText;
    final english = s.englishHeaderText;
    final b64 = s.logoBase64;
    if (arabic.isEmpty && english.isEmpty && (b64 == null || b64.isEmpty)) return;

    final hasLogo = b64 != null && b64.isNotEmpty;

    late Uint8List? logoBytes;
    late String? logoExt;
    if (hasLogo) {
      try {
        logoBytes = base64Decode(b64);
        logoExt = s.logoFileName?.endsWith('.png') == true ? 'png' : 'jpeg';
      } catch (_) {
        logoBytes = null;
        logoExt = null;
      }
    }

    const logoSz = 40.0;
    final cells = <DocxTableCell>[];

    cells.add(DocxTableCell(
      verticalAlign: DocxVerticalAlign.center,
      children: [
        DocxParagraph(align: DocxAlign.left, children: [
          if (english.isNotEmpty) DocxText(english) else DocxText(''),
        ]),
      ],
    ));

    if (hasLogo) {
      cells.add(DocxTableCell(
        verticalAlign: DocxVerticalAlign.center,
        children: [
          if (logoBytes != null)
            DocxImage(
              bytes: logoBytes,
              extension: logoExt ?? 'png',
              width: logoSz,
              height: logoSz,
              align: DocxAlign.center,
            )
          else
            DocxParagraph(children: [DocxText('')]),
        ],
      ));
    }

    cells.add(DocxTableCell(
      verticalAlign: DocxVerticalAlign.center,
      children: [
        DocxParagraph(align: DocxAlign.right, children: [
          if (arabic.isNotEmpty) DocxText(arabic) else DocxText(''),
        ]),
      ],
    ));

    builder.addTable(DocxTable(
      rows: [DocxTableRow(cells: cells)],
      style: DocxTableStyle.plain,
      width: 5000,
      widthType: DocxWidthType.pct,
      gridColumns: hasLogo ? [3800, 2600, 3800] : [6000, 6000],
      alignment: DocxAlign.center,
    ));
  }

  /// Case diagnosis table: merged title row + 3-column data grid.
  /// Each cell contains "label: value" to avoid RTL column shifting.
  static void _addCompactCaseTable(
    DocxDocumentBuilder builder,
    WordReportModel model,
    CenterReportSettings? s,
  ) {
    const border = DocxBorder.single;
    const borderColor = '4472C4';
    const borderWidth = 4;

    final yearStr = model.year > 0 ? ' ${model.year}م' : '';
    final titleCell = DocxTableCell(
      colSpan: 3,
      verticalAlign: DocxVerticalAlign.center,
      children: [
        DocxParagraph(align: DocxAlign.center, children: [
          DocxText.bold('بيانات الحالة والتشخيص تقييم$yearStr'),
        ]),
      ],
    );

    final dataFields = <List<String>>[
      ['الاسم: ${model.studentName}',
       'نوع ودرجة الإعاقة: ${model.diagnosis}',
       'البرنامج: ${model.programType}'],
      ['الجنس: ذكر □  أنثى □',
       'تاريخ الميلاد: ${model.studentAge.isNotEmpty ? model.studentAge : ''}',
       'المستوى الصفي: '],
    ];

    if (s != null && s.reportsToFund) {
      final fundRow = <String>[];
      if (s.fundName.isNotEmpty) fundRow.add('الجهة الداعمة: ${s.fundName}');
      if (s.showFundCardNumber) fundRow.add('رقم بطاقة الصندوق: ');
      if (s.showReferralDate) fundRow.add('تاريخ الإرسالية: ');
      if (s.showReferralSource) fundRow.add('جهة الإرسال: ${model.centerName}');
      if (fundRow.isNotEmpty) dataFields.add(fundRow);
    }

    final tblRows = dataFields.map((row) {
      while (row.length < 3) {
        row.add('');
      }
      final reversed = row.reversed.toList();
      final cells = reversed.map((text) => DocxTableCell.text(
        text,
        align: DocxAlign.right,
        verticalAlign: DocxVerticalAlign.center,
      )).toList();
      return DocxTableRow(cells: cells);
    }).toList();

    builder.addTable(DocxTable(
      rows: [DocxTableRow(cells: [titleCell]), ...tblRows],
      style: DocxTableStyle(
        border: border,
        borderColor: borderColor,
        borderWidth: borderWidth,
      ),
      width: 5000,
      widthType: DocxWidthType.pct,
      gridColumns: [3500, 5400, 3500],
      alignment: DocxAlign.center,
    ));
  }

  /// Compact rediagnosis: label in left cell, numbered blanks in right.
  static void _addCompactRediagnosisTable(
    DocxDocumentBuilder builder,
    WordReportModel model,
  ) {
    builder.addTable(DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(
            verticalAlign: DocxVerticalAlign.center,
            children: [
              DocxParagraph(align: DocxAlign.right, children: [
                DocxText.bold('إعادة تشخيص الحالة بداية التقرير:'),
              ]),
              DocxParagraph(align: DocxAlign.right, children: [
                DocxText('بعد إعادة التشخيص، تحتاج الحالة إلى:'),
              ]),
            ],
          ),
          DocxTableCell(
            verticalAlign: DocxVerticalAlign.center,
            children: [
              DocxParagraph(align: DocxAlign.right, children: [DocxText('1- ')]),
              DocxParagraph(align: DocxAlign.right, children: [DocxText('2- ')]),
              DocxParagraph(align: DocxAlign.right, children: [DocxText('3- ')]),
            ],
          ),
        ]),
      ],
      style: const DocxTableStyle(
        border: DocxBorder.single,
        borderColor: '4472C4',
        borderWidth: 4,
      ),
      width: 5000,
      widthType: DocxWidthType.pct,
      gridColumns: [9000, 5000],
      alignment: DocxAlign.center,
    ));
  }

  /// Horizontal services table: 2 rows, 6 columns.
  static void _addCompactServicesTable(
    DocxDocumentBuilder builder,
    WordReportModel model,
  ) {
    final names = model.activeServiceNames;

    bool match(Iterable<String> keywords) =>
        names.any((n) => keywords.any((kw) => n.contains(kw)));

    final services = [
      ('البرنامج التربوي/الدراسي', ['تربوي', 'دراسي', 'تعليمي']),
      ('العلاج النطقي',           ['نطق', 'النطق والتخاطب']),
      ('العلاج الوظيفي',          ['وظيفي', 'العلاج الوظيفي']),
      ('التكامل الحسي',           ['تكامل', 'حسي']),
      ('تعديل السلوك',            ['سلوك']),
    ];

    final headerCells = <DocxTableCell>[
      DocxTableCell.text('البرنامج / نوع الخدمة', isBold: true,
          align: DocxAlign.right, verticalAlign: DocxVerticalAlign.center,
          shadingFill: 'E0F2FE'),
      ...services.map((s) => DocxTableCell.text(s.$1, isBold: true,
          align: DocxAlign.center, verticalAlign: DocxVerticalAlign.center,
          shadingFill: 'E0F2FE')),
    ];

    final dataCells = <DocxTableCell>[
      DocxTableCell.text('الحالة',
          align: DocxAlign.right, verticalAlign: DocxVerticalAlign.center),
      ...services.map((s) => DocxTableCell.text(
          match(s.$2) ? 'نعم' : '',
          align: DocxAlign.center, verticalAlign: DocxVerticalAlign.center)),
    ];

    builder.addTable(DocxTable(
      rows: [
        DocxTableRow(cells: headerCells),
        DocxTableRow(cells: dataCells),
      ],
      style: const DocxTableStyle(
        border: DocxBorder.single,
        borderColor: '4472C4',
        borderWidth: 4,
        headerFill: 'E0F2FE',
      ),
      width: 5000,
      widthType: DocxWidthType.pct,
      hasHeader: true,
      alignment: DocxAlign.center,
    ));
  }

  /// Compact eval + recommendations + signature table (2 rows).
  static void _addCompactEvalRecTable(
    DocxDocumentBuilder builder,
    WordReportModel model,
    CenterReportSettings? s,
  ) {
    final evalCell = DocxTableCell(
      colSpan: 2,
      verticalAlign: DocxVerticalAlign.center,
      children: [
        DocxParagraph(align: DocxAlign.right, children: [
          DocxText.bold('تقييم مستوى الطفل بعد تلقي خدمات المركز خلال التقرير:'),
        ]),
        DocxParagraph(align: DocxAlign.right, children: [DocxText('1- ')]),
        DocxParagraph(align: DocxAlign.right, children: [DocxText('2- ')]),
      ],
    );
    final recCell = DocxTableCell(
      verticalAlign: DocxVerticalAlign.center,
      children: [
        DocxParagraph(align: DocxAlign.right, children: [
          DocxText.bold('التوصيات:'),
        ]),
        DocxParagraph(align: DocxAlign.right, children: [DocxText('1- ')]),
        DocxParagraph(align: DocxAlign.right, children: [DocxText('2- ')]),
      ],
    );
    builder.addTable(DocxTable(
      rows: [
        DocxTableRow(cells: [evalCell]),
        DocxTableRow(cells: [recCell, _addCompactSignatureCell(s)]),
      ],
      style: const DocxTableStyle(
        border: DocxBorder.single,
        borderColor: '4472C4',
        borderWidth: 4,
      ),
      width: 5000,
      widthType: DocxWidthType.pct,
      gridColumns: [5000, 9000],
      alignment: DocxAlign.center,
    ));

    final notes = s?.footerNotes;
    if (notes != null && notes.isNotEmpty) {
      builder.p(notes, align: DocxAlign.right);
    }
  }

  /// Signature cell: supervisor name and signature/date placeholders.
  static DocxTableCell _addCompactSignatureCell(CenterReportSettings? s) {
    final supervisorName = s?.defaultTechnicalSupervisorName ?? '';
    final sigText = supervisorName.isNotEmpty
        ? 'المشرف الفني: $supervisorName    التوقيع: __________    التاريخ: __________'
        : 'المشرف الفني: __________    التوقيع: __________    التاريخ: __________';
    return DocxTableCell(
      verticalAlign: DocxVerticalAlign.top,
      children: [
        DocxParagraph(align: DocxAlign.right, children: [
          DocxText(sigText),
        ]),
      ],
    );
  }

  // =================================================================
  //  PAGE 2 — Evaluation table page (Entirely Portrait)
  // =================================================================

  static void _buildPortraitEvaluationPage(
    DocxDocumentBuilder builder,
    WordReportModel model,
  ) {
    final periodName = _extractPeriodName(model.dateRange);
    final periodLabel = model.months.isNotEmpty && periodName.isNotEmpty
        ? 'التقرير $periodName - الأشهر ${model.months.join(' / ')} - ${model.year}'
        : model.dateRange;

    builder
      ..paragraph(DocxParagraph.heading1(
        'التقرير الربع سنوي للحالة',
        align: DocxAlign.right,
      ))
      ..p(periodLabel, align: DocxAlign.right)
      ..p('${model.centerName} | ${model.studentName}',
          align: DocxAlign.right)
      ..p('', align: DocxAlign.right)
      ..p('الدرجة 2 = يستطيع أداء المهارة باستقلالية',
          align: DocxAlign.right)
      ..p('الدرجة 1 = يستطيع أداء المهارة جزئيًا أو بمساعدة',
          align: DocxAlign.right)
      ..p('الدرجة 0 = لا يستطيع أداء المهارة نهائيًا',
          align: DocxAlign.right);

    for (final section in model.sections) {
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
  }

  // =================================================================
  //  HELPERS
  // =================================================================

  /// Column widths for Portrait evaluation tables (5000 = 100%).
  static List<int>? _gridColumns(int count) {
    switch (count) {
      case 8:
        return [1100, 1000, 2700, 450, 450, 450, 450, 900];
      case 7:
        return [1100, 1000, 2700, 450, 450, 450, 900];
      case 6:
        return [1100, 1000, 2700, 450, 450, 900];
      case 5:
        return [1100, 1000, 2700, 450, 900];
      case 4:
        return [1100, 1000, 2700, 900];
      case 3:
        return [2200, 4400, 3400];
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
      programType: 'نطق وتخاطب',
      diagnosis: 'اضطراب النطق',
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

  static String _extractPeriodName(String dateRange) {
    final regex = RegExp(r'^التقرير\s+(.+?)\s*-\s*\d+\s*$');
    final match = regex.firstMatch(dateRange);
    return match?.group(1) ?? '';
  }

  static String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
