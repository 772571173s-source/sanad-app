import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';
import 'report_comparison_service.dart';
import 'report_data_builder.dart';

class SmartPdfReportService {
  static const _primary = PdfColor.fromInt(0xFF0F766E);
  static const _background = PdfColor.fromInt(0xFFF8FAF7);
  static const _text = PdfColor.fromInt(0xFF1F2937);
  static const _accentBlue = PdfColor.fromInt(0xFFE0F2FE);
  static const _accentGreen = PdfColor.fromInt(0xFFDCFCE7);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _primaryLight = PdfColor.fromInt(0xFFB2D8D4);
  static const _muted = PdfColor.fromInt(0xFF64748B);

  Future<Uint8List> buildSmartReportPdfBytes(ReportData data,
      {String specialistSignature = '',
      String managerSignature = '',
      String reportCategory = 'general',
      ReportComparisonResult? comparison,
      String? quarter,
      String? year,
      bool isDemo = false}) async {
    final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => _buildContent(font, data,
            specialistSignature: specialistSignature,
            managerSignature: managerSignature,
            reportCategory: reportCategory,
            comparison: comparison,
            quarter: quarter,
            year: year,
            isDemo: isDemo),
      ),
    );
    return pdf.save();
  }

  Future<void> printReport(ReportData data,
      {String specialistSignature = '',
      String managerSignature = ''}) async {
    final bytes = await buildSmartReportPdfBytes(data,
        specialistSignature: specialistSignature,
        managerSignature: managerSignature);
    final name =
        'sanad-report-${data.student.id}-${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
  }

  List<pw.Widget> _buildContent(pw.Font font, ReportData data,
      {String specialistSignature = '',
      String managerSignature = '',
      String reportCategory = 'general',
      ReportComparisonResult? comparison,
      String? quarter,
      String? year,
      bool isDemo = false}) {
    final widgets = <pw.Widget>[];
    if (isDemo) {
      widgets.add(_demoWatermark(font));
      widgets.add(pw.SizedBox(height: 8));
    }
    widgets.addAll([
      _header(font, data),
      pw.SizedBox(height: 14),
      _reportTitleSection(font, data, reportCategory, quarter, year),
      pw.SizedBox(height: 10),
      _studentInfoBox(font, data),
      pw.SizedBox(height: 14),
    ]);

    // Add comparison section for followup reports
    // Always shown when comparison exists, even if no changes.
    if (comparison != null &&
        (reportCategory == 'specialistFollowup' ||
            reportCategory == 'supervisorQuarterly')) {
      widgets.addAll(_comparisonSection(font, comparison, reportCategory));
      widgets.add(pw.SizedBox(height: 14));
    }
    if (data.scope == 'allPrograms' && data.sections.length > 1) {
      widgets.addAll(_overallSummary(font, data));
      widgets.add(pw.SizedBox(height: 14));
    }

    for (int i = 0; i < data.sections.length; i++) {
      final section = data.sections[i];
      widgets.add(_programHeader(font, section, i + 1));
      widgets.add(pw.SizedBox(height: 10));
      widgets.addAll(_programSummary(font, section));
      widgets.add(pw.SizedBox(height: 12));
      widgets.addAll(_assessmentsSection(font, section));
      widgets.add(pw.SizedBox(height: 10));
      widgets.addAll(_goalsSection(font, section));
      widgets.add(pw.SizedBox(height: 10));
      widgets.addAll(_sessionsSection(font, section));
      widgets.add(pw.SizedBox(height: 10));
      widgets.addAll(_stepsSection(font, section));
      if (section.sessions.isEmpty && section.assessments.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(_arBullet(font, 'ملاحظة: لم تبدأ الجلسات العلاجية بعد.', fontSize: 10));
      }
      if (i < data.sections.length - 1) {
        widgets.add(_sectionDivider(font));
        widgets.add(pw.SizedBox(height: 14));
      }
    }

    widgets.addAll([
      pw.SizedBox(height: 14),
      _sectionTitle(font, 'التوصيات'),
      pw.SizedBox(height: 8),
      _recommendationsBox(font, data),
      pw.SizedBox(height: 24),
      _signatures(font, specialistSignature, managerSignature),
      _footer(font),
    ]);

    return widgets;
  }

  pw.Widget _header(pw.Font font, ReportData data) {
    final now = DateTime.now().toIso8601String().split('T').first;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _background,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 78,
            height: 78,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _accentGreen,
              border: pw.Border.all(color: _primary),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text('سند',
                style: pw.TextStyle(
                    font: font,
                    fontSize: 22,
                    color: _primary,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(data.center?.name ?? 'مركز سند',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 21,
                      color: _text,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(data.center?.address ?? '',
                  style: pw.TextStyle(font: font, color: _text)),
              pw.Text('تاريخ التقرير: $now',
                  style: pw.TextStyle(font: font)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _studentInfoBox(pw.Font font, ReportData data) {
    final student = data.student;
    final period = data.dateFrom.isNotEmpty
        ? 'من ${data.dateFrom} إلى ${data.dateTo}'
        : 'بدون فترة محددة';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoLine(font, 'الطالب', student.name),
          _infoLine(font, 'العمر', '${student.age} سنة'),
          _infoLine(font, 'التشخيص', student.diagnosis),
          if (student.parentName.isNotEmpty)
            _infoLine(font, 'ولي الأمر', student.parentName),
          if (student.parentPhone.isNotEmpty)
            _infoLine(font, 'رقم ولي الأمر', student.parentPhone),
          _infoLine(font, 'نوع التقرير', data.type),
          if (data.createdByName.isNotEmpty)
            _infoLine(font, 'أعدّ التقرير', data.createdByName),
          if (data.scope == 'allPrograms')
            _infoLine(font, 'نطاق التقرير', 'جميع البرامج'),
          _infoLine(font, 'الفترة', period),
        ],
      ),
    );
  }

  pw.Widget _infoLine(pw.Font font, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(value,
              style: pw.TextStyle(font: font, fontSize: 11)),
        ],
      ),
    );
  }

  List<pw.Widget> _overallSummary(pw.Font font, ReportData data) {
    const mw3 = (539.28 - 16) / 3;
    return [
      _sectionTitle(font, 'ملخص عام'),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          _metricBox(font, 'عدد البرامج', '${data.totalSections}', width: mw3),
          pw.SizedBox(width: 8),
          _metricBox(font, 'الجلسات', '${data.totalSessions}', width: mw3),
          pw.SizedBox(width: 8),
          _metricBox(font, 'الأهداف الكلية', '${data.totalPlans}', width: mw3),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          _metricBox(font, 'الأهداف المنجزة', '${data.totalMasteredGoals}', width: mw3),
          pw.SizedBox(width: 8),
          _metricBox(font, 'الأهداف النشطة', '${data.totalActiveGoals}', width: mw3),
          pw.SizedBox(width: 8),
          _metricBox(font, 'نسبة التقدم', '${data.overallImprovementRate}%', width: mw3),
        ],
      ),
    ];
  }

  pw.Widget _programHeader(
      pw.Font font, ProgramReportSection section, int index) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _primary,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'القسم $index: ${section.programName}',
        style: pw.TextStyle(
            font: font,
            fontSize: 15,
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  List<pw.Widget> _programSummary(pw.Font font, ProgramReportSection section) {
    const pmw3 = (519.28 - 16) / 3;
    return [
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (section.specialistName.isNotEmpty)
              _infoLine(font, 'الأخصائي المسؤول', section.specialistName),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                _metricBox(font, 'الأهداف', '${section.plans.length}', width: pmw3),
                pw.SizedBox(width: 8),
                _metricBox(
                    font, 'منها standard', '${section.standardGoalCount}', width: pmw3),
                pw.SizedBox(width: 8),
                _metricBox(
                    font, 'منها نطق', '${section.speechSoundGoalCount}', width: pmw3),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                _metricBox(
                    font, 'مُنجز', '${section.masteredGoals}', width: pmw3),
                pw.SizedBox(width: 8),
                _metricBox(font, 'نشط', '${section.activeGoals}', width: pmw3),
                pw.SizedBox(width: 8),
                _metricBox(
                    font, 'التقدم', '${section.overallProgress}%', width: pmw3),
              ],
            ),
            if (section.totalSessions > 0) ...[
              pw.SizedBox(height: 6),
              _metricBox(
                  font, 'الجلسات في الفترة', '${section.totalSessions}'),
            ],
          ],
        ),
      ),
    ];
  }

  List<pw.Widget> _assessmentsSection(
      pw.Font font, ProgramReportSection section) {
    if (section.assessments.isEmpty) return [];
    return [
      _subSectionTitle(font, 'التقييمات'),
      pw.SizedBox(height: 6),
      ...section.assessments.take(3).map((a) => _arBullet(
            font,
            '${a.specialistName} - ${a.createdAt.split('T').first}',
            fontSize: 10.5,
          )),
      if (section.findings.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text('عدد نقاط التقييم: ${section.findings.length}',
            style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: _muted)),
      ],
    ];
  }

  List<pw.Widget> _goalsSection(pw.Font font, ProgramReportSection section) {
    if (section.plans.isEmpty) return [];
    final widgets = <pw.Widget>[
      _subSectionTitle(font, 'الأهداف العلاجية'),
      pw.SizedBox(height: 6),
    ];

    final standard = section.standardPlans;
    final speech = section.speechSoundPlans;

    if (standard.isNotEmpty) {
      widgets.add(pw.Text('أقسام التقييم',
          style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 4));
      for (final plan in standard) {
        final progress = _goalProgress(section, plan.id);
        widgets.add(_goalRow(font, plan.goal, progress,
            section.stepsForPlan(plan.id)));
      }
      widgets.add(pw.SizedBox(height: 8));
    }

    if (speech.isNotEmpty) {
      widgets.add(pw.Text('حروف النطق',
          style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 4));
      for (final plan in speech) {
        final progress = _goalProgress(section, plan.id);
        widgets.add(_goalRow(font, plan.goal, progress,
            section.stepsForPlan(plan.id)));
      }
    }

    return widgets;
  }

  int _goalProgress(ProgramReportSection section, String planId) {
    final steps = section.stepsForPlan(planId);
    if (steps.isEmpty) {
      final matches = section.sessions
          .where((s) => s.planId == planId)
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (matches.isEmpty) return 0;
      switch (matches.first.quickResult) {
        case 'متقن':
          return 100;
        case 'بمساعدة':
          return 50;
        default:
          return 0;
      }
    }
    final completed = steps.where((s) => s.status == 'متقن').length;
    return ((completed / steps.length) * 100).round();
  }

  pw.Widget _goalRow(
      pw.Font font, String goal, int progress, List<GoalSkillStep> steps) {
    final mastered = steps.where((s) => s.status == 'متقن').length;
    final needsHelp =
        steps.where((s) => s.status == 'بمساعدة').length;
    final needsRetry =
        steps.where((s) => s.status == 'يحتاج إعادة').length;
    final notStarted =
        steps.where((s) => s.status == 'لم يبدأ' || s.status.isEmpty).length;

    final stepsSummary = steps.isEmpty
        ? ''
        : ' (متقن: $mastered، بمساعدة: $needsHelp، يحتاج إعادة: $needsRetry، لم يبدأ: $notStarted)';
    return _arBullet(font, '$goal - تقدم $progress%$stepsSummary',
        fontSize: 10.5);
  }

  List<pw.Widget> _sessionsSection(
      pw.Font font, ProgramReportSection section) {
    if (section.sessions.isEmpty) return [];
    return [
      _subSectionTitle(font, 'الجلسات'),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: _border, width: 0.7),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.2),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _accentBlue),
            children: [
              _cell(font, 'التاريخ', bold: true),
              _cell(font, 'المهارة', bold: true),
              _cell(font, 'النتيجة', bold: true),
              _cell(font, 'النجاح', bold: true),
            ],
          ),
          ...section.sessions.map((session) => pw.TableRow(children: [
                _cell(font, session.startedAt.split('T').first),
                _cell(font, session.cardTitle),
                _cell(font, session.quickResult),
                _cell(font, '${session.successRate}%'),
              ])),
        ],
      ),
    ];
  }

  List<pw.Widget> _stepsSection(pw.Font font, ProgramReportSection section) {
    if (section.goalSkillSteps.isEmpty) return [];
    final mastered =
        section.goalSkillSteps.where((s) => s.status == 'متقن').length;
    final assisted =
        section.goalSkillSteps.where((s) => s.status == 'بمساعدة').length;
    final retry = section.goalSkillSteps
        .where((s) => s.status == 'يحتاج إعادة')
        .length;
    final notStarted = section.goalSkillSteps
        .where((s) => s.status == 'لم يبدأ' || s.status.isEmpty)
        .length;
    const smw4 = (539.28 - 24) / 4;

    return [
      _subSectionTitle(font, 'المهارات (الخطوات)'),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          _metricBox(font, 'متقن', '$mastered',
              color: const PdfColor.fromInt(0xFF16A34A), width: smw4),
          pw.SizedBox(width: 8),
          _metricBox(font, 'بمساعدة', '$assisted',
              color: const PdfColor.fromInt(0xFFD97706), width: smw4),
          pw.SizedBox(width: 8),
          _metricBox(font, 'يحتاج إعادة', '$retry',
              color: const PdfColor.fromInt(0xFFDC2626), width: smw4),
          pw.SizedBox(width: 8),
          _metricBox(font, 'لم يبدأ', '$notStarted',
              color: _muted, width: smw4),
        ],
      ),
    ];
  }

  pw.Widget _recommendationsBox(pw.Font font, ReportData data) {
    final recs = <String>[];
    for (final section in data.sections) {
      if (section.goalSkillSteps
          .any((s) => s.status == 'يحتاج إعادة')) {
        recs.add(
            'برنامج ${section.programName}: توجد مهارات تحتاج إعادة تدريب.');
      }
    }
    if (recs.isEmpty) {
      recs.add('الحمد لله، جميع المهارات تسير بشكل جيد.');
    }
    recs.add('يوصى بالاستمرار على الأنشطة الأعلى نجاحًا.');
    if (data.totalSessions > 0) {
      recs.add(
          'تم تسجيل ${data.totalSessions} جلسات في الفترة المحددة.');
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: recs
            .map((r) => _arBullet(font, r, fontSize: 11))
            .toList(),
      ),
    );
  }

  pw.Widget _sectionTitle(pw.Font font, String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _accentBlue,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _subSectionTitle(pw.Font font, String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _accentGreen,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _sectionDivider(pw.Font font) {
    return pw.Container(
      height: 2,
      color: _primaryLight,
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
    );
  }

  pw.Widget _metricBox(pw.Font font, String label, String value,
      {PdfColor? color, double width = 150}) {
    final accent = color ?? _primary;
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  color: accent,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: pw.TextStyle(font: font, fontSize: 9)),
        ],
      ),
    );
  }

  /// RTL-safe Arabic bullet point.
  /// Uses a single pw.Text with a `-` prefix instead of pw.Bullet,
  /// which breaks RTL rendering (bullet on the wrong side / huge gap).
  pw.Widget _arBullet(pw.Font font, String text, {double fontSize = 11}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        '- $text',
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
    );
  }

  pw.Widget _cell(pw.Font font, String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _signatures(
      pw.Font font, String specialistSignature, String managerSignature) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (specialistSignature.isNotEmpty)
          pw.Text('توقيع الأخصائي: $specialistSignature',
              style: pw.TextStyle(font: font, fontSize: 12)),
        if (managerSignature.isNotEmpty)
          pw.Text('توقيع المدير: $managerSignature',
              style: pw.TextStyle(font: font, fontSize: 12)),
      ],
    );
  }

  pw.Widget _demoWatermark(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF3CD),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFFC107)),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('⚠ ',
              style: pw.TextStyle(font: font, fontSize: 14, color: const PdfColor.fromInt(0xFF856404))),
          pw.Text(
            'تقرير تجريبي - غير مخصص للاستخدام الرسمي',
            style: pw.TextStyle(
              font: font,
              fontSize: 13,
              color: const PdfColor.fromInt(0xFF856404),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16),
      child: pw.Center(
        child: pw.Text(
          'تم إنشاء التقرير بواسطة منصة سند لإدارة الجلسات والبرامج العلاجية',
          style: pw.TextStyle(
              font: font, fontSize: 8, color: PdfColors.grey600),
        ),
      ),
    );
  }

  pw.Widget _reportTitleSection(pw.Font font, ReportData data,
      String reportCategory, String? quarter, String? year) {
    final title = _categoryTitle(reportCategory);
    final sub = _categorySubtitle(reportCategory, quarter, year);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _primary,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold)),
          if (sub != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(sub,
                style: pw.TextStyle(
                    font: font, fontSize: 11, color: PdfColors.white)),
          ],
        ],
      ),
    );
  }

  String _categoryTitle(String reportCategory) {
    switch (reportCategory) {
      case 'specialistInitial':
        return 'تقرير علاجي أولي';
      case 'specialistFollowup':
        return 'تقرير متابعة علاجي';
      case 'supervisorQuarterly':
        return 'تقرير إشرافي ربع سنوي';
      default:
        return 'تقرير علاجي';
    }
  }

  String? _categorySubtitle(
      String reportCategory, String? quarter, String? year) {
    switch (reportCategory) {
      case 'specialistInitial':
        return 'هذا التقرير مبني على التقييم الأولي للطالب.';
      case 'specialistFollowup':
        return 'مقارنة مع التقرير السابق';
      case 'supervisorQuarterly':
        if (quarter != null && year != null) {
          return 'الربع: $quarter - السنة: $year';
        }
        return 'تقرير إشرافي ربع سنوي';
      default:
        return null;
    }
  }

  List<pw.Widget> _comparisonSection(pw.Font font,
      ReportComparisonResult comparison, String reportCategory) {
    final widgets = <pw.Widget>[
      _sectionTitle(font, 'مقارنة مع التقرير السابق'),
      pw.SizedBox(height: 8),
    ];

    final hasChanges = comparison.sessionsSincePreviousReport > 0 ||
        comparison.goalsProgressChanged.isNotEmpty ||
        comparison.masteredGoals.isNotEmpty ||
        comparison.stagnantGoalIds.isNotEmpty ||
        comparison.newGoalIds.isNotEmpty ||
        comparison.improvedWeaknesses.isNotEmpty ||
        comparison.remainingWeaknesses.isNotEmpty;

    if (!hasChanges) {
      widgets.add(_arBullet(
          font, 'لا توجد تغييرات علاجية جديدة منذ التقرير السابق.',
          fontSize: 11));
      widgets.add(pw.SizedBox(height: 4));
    }

    if (comparison.sessionsSincePreviousReport > 0) {
      widgets.add(_arBullet(
          font,
          'عدد الجلسات منذ التقرير السابق: ${comparison.sessionsSincePreviousReport}',
          fontSize: 11));
      widgets.add(pw.SizedBox(height: 4));
    }

    if (comparison.masteredGoals.isNotEmpty) {
      widgets.add(_arBullet(
          font,
          'الأهداف المتقنة: ${comparison.masteredGoals.length}',
          fontSize: 11));
      for (final g in comparison.masteredGoals) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(right: 12, bottom: 2),
          child: pw.Text('- ${g.goalTitle}',
              style: pw.TextStyle(font: font, fontSize: 10)),
        ));
      }
      widgets.add(pw.SizedBox(height: 4));
    }

    if (comparison.goalsProgressChanged.isNotEmpty) {
      for (final g in comparison.goalsProgressChanged) {
        if (g.currentProgress < 100) {
          widgets.add(_arBullet(
              font,
              'تحسن هدف "${g.goalTitle}" من ${g.previousProgress}% إلى ${g.currentProgress}% (${g.delta > 0 ? '+' : ''}${g.delta}%)',
              fontSize: 10));
        }
      }
      widgets.add(pw.SizedBox(height: 4));
    }

    if (comparison.stagnantGoalIds.isNotEmpty) {
      widgets.add(_arBullet(
          font,
          'أهداف لم تتحسن: ${comparison.stagnantGoalIds.length}',
          fontSize: 11));
      for (final planId in comparison.stagnantGoalIds) {
        final title = comparison.goalsProgressChanged
            .where((g) => g.planId == planId)
            .firstOrNull?.goalTitle;
        if (title != null) {
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(right: 12, bottom: 2),
            child: pw.Text('- $title',
                style: pw.TextStyle(font: font, fontSize: 10)),
          ));
        }
      }
    }

    if (comparison.newGoalIds.isNotEmpty) {
      widgets.add(_arBullet(
          font,
          'أهداف جديدة مضافة: ${comparison.newGoalIds.length}',
          fontSize: 11));
    }

    if (reportCategory == 'supervisorQuarterly') {
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(_subSectionTitle(font, 'توصيات المشرف الفني'));
      widgets.add(pw.SizedBox(height: 4));
      if (comparison.stagnantGoalIds.isNotEmpty) {
        widgets.add(_arBullet(font,
            'يوجد ${comparison.stagnantGoalIds.length} أهداف متعثرة تحتاج مراجعة الخطة العلاجية.',
            fontSize: 10));
      }
      if (comparison.masteredGoals.isNotEmpty) {
        widgets.add(_arBullet(font,
            'تم إتقان ${comparison.masteredGoals.length} أهداف. يوصى بالاستمرار على البرنامج الحالي.',
            fontSize: 10));
      }
    }

    return widgets;
  }
}
