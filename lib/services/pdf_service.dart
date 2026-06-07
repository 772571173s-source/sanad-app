import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';

class PdfService {
  static const _primary = PdfColor.fromInt(0xFF0F766E);
  static const _background = PdfColor.fromInt(0xFFF8FAF7);
  static const _text = PdfColor.fromInt(0xFF1F2937);
  static const _accentBlue = PdfColor.fromInt(0xFFE0F2FE);
  static const _accentGreen = PdfColor.fromInt(0xFFDCFCE7);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);

  Future<void> printStudentCredentials(Student student) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Theme(
            data: pw.ThemeData.withFont(base: font),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'سند - بيانات دخول ولي الأمر',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text('الطالب: ${student.name}',
                    style: pw.TextStyle(font: font, fontSize: 16)),
                pw.SizedBox(height: 12),
                _credentialRow(
                    font: font,
                    label: 'اسم المستخدم',
                    value: student.portalEmail),
                pw.SizedBox(height: 8),
                _credentialRow(
                    font: font,
                    label: 'كلمة المرور',
                    value: student.portalPassword),
              ],
            ),
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
        name: 'sanad-login-${student.id}.pdf', onLayout: (_) => pdf.save());
  }

  Future<void> printProgressReport({
    SanadCenter? center,
    required Student student,
    required List<TherapySession> sessions,
    required List<Evaluation> evaluations,
    required List<TrainingPlan> plans,
    required List<ReportRecord> reports,
    required String type,
    required String specialistSignature,
    required String managerSignature,
  }) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final improvement = evaluations.isEmpty
        ? _sessionAverage(sessions)
        : _improvementRate(evaluations);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => [
          _reportHeader(font, center, _today()),
          pw.SizedBox(height: 14),
          _sectionTitle(font, 'تقرير سند - $type'),
          pw.SizedBox(height: 10),
          _infoBox(font, [
            'الطالب: ${student.name}',
            'العمر: ${student.age}',
            'التشخيص: ${student.diagnosis}',
            'ولي الأمر: ${student.parentName}',
            'رقم ولي الأمر: ${student.parentPhone}',
          ]),
          pw.SizedBox(height: 14),
          _performanceSummary(font, sessions, improvement),
          pw.SizedBox(height: 14),
          _sectionTitle(font, 'الجلسات داخل التقرير'),
          if (sessions.isEmpty)
            pw.Text('لا توجد جلسات مسجلة داخل الفترة.',
                style: pw.TextStyle(font: font))
          else
            _sessionsTable(font, sessions),
          pw.SizedBox(height: 14),
          _sectionTitle(font, 'الخطة التدريبية'),
          if (plans.isEmpty)
            pw.Text('لا توجد أهداف مسجلة.', style: pw.TextStyle(font: font)),
          ...plans.map((plan) => pw.Bullet(
                text: '${plan.goal} - تقدم ${plan.progress}%',
                style: pw.TextStyle(font: font),
              )),
          pw.SizedBox(height: 14),
          _sectionTitle(font, 'تقييم نطق الحروف'),
          if (evaluations.isEmpty)
            pw.Text('لا توجد تقييمات مسجلة.', style: pw.TextStyle(font: font)),
          ...evaluations.take(18).map((evaluation) => pw.Bullet(
                text:
                    '${evaluation.letter} - ${evaluation.position} - ${evaluation.errorType} - ${evaluation.score}',
                style: pw.TextStyle(font: font),
              )),
          pw.SizedBox(height: 14),
          _sectionTitle(font, 'التوصيات والخطة القادمة'),
          _infoBox(font, [
            sessions.isEmpty
                ? 'يوصى ببدء جلسات منتظمة لتكوين خط أساس واضح.'
                : 'يوصى بالاستمرار على الأنشطة الأعلى نجاحًا، وإعادة تدريب الأنشطة الأقل أداء بخطوات أقصر.',
            'عدد التقارير السابقة داخل ملف الطالب: ${reports.length}',
            'الخطة القادمة: متابعة الأهداف الحالية وتحديث الخطة عند ثبات الأداء.',
          ]),
          pw.SizedBox(height: 24),
          _signatures(font, specialistSignature, managerSignature),
          _reportFooter(font),
        ],
      ),
    );
    await Printing.layoutPdf(
        name: 'sanad-report-${student.id}.pdf', onLayout: (_) => pdf.save());
  }

  pw.Widget _credentialRow({
    required pw.Font font,
    required String label,
    required String value,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Text(value,
              textAlign: pw.TextAlign.left,
              style: pw.TextStyle(font: font, fontSize: 16)),
        ),
        pw.SizedBox(width: 8),
        pw.Text('$label:', style: pw.TextStyle(font: font, fontSize: 16)),
      ],
    );
  }

  pw.Widget _reportHeader(pw.Font font, SanadCenter? center, String date) {
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
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(center?.name ?? 'مركز سند',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 21,
                        color: _text,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(center?.address ?? 'العنوان غير محدد',
                    style: pw.TextStyle(font: font, color: _text)),
                pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(center?.phone ?? '',
                      style: pw.TextStyle(font: font),
                      textAlign: pw.TextAlign.left),
                ),
                pw.Text('تاريخ التقرير: $date',
                    style: pw.TextStyle(font: font)),
              ],
            ),
          ),
        ],
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

  pw.Widget _infoBox(pw.Font font, List<String> lines) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines
            .map((line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(line, style: pw.TextStyle(font: font)),
                ))
            .toList(),
      ),
    );
  }

  pw.Widget _performanceSummary(
      pw.Font font, List<TherapySession> sessions, int improvement) {
    final count = sessions.length;
    final strong =
        sessions.where((session) => session.successRate >= 80).length;
    final needsSupport =
        sessions.where((session) => session.successRate < 60).length;
    return pw.Row(
      children: [
        _metricBox(font, 'عدد الجلسات', '$count'),
        pw.SizedBox(width: 8),
        _metricBox(font, 'نسبة الأداء', '$improvement%'),
        pw.SizedBox(width: 8),
        _metricBox(font, 'أداء قوي', '$strong'),
        pw.SizedBox(width: 8),
        _metricBox(font, 'يحتاج دعم', '$needsSupport'),
      ],
    );
  }

  pw.Widget _metricBox(pw.Font font, String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  pw.Widget _sessionsTable(pw.Font font, List<TherapySession> sessions) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: .7),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _accentBlue),
          children: [
            _cell(font, 'التاريخ', bold: true),
            _cell(font, 'المهارة', bold: true),
            _cell(font, 'الأنشطة', bold: true),
            _cell(font, 'النجاح', bold: true),
          ],
        ),
        ...sessions.map((session) => pw.TableRow(children: [
              _cell(font, session.startedAt.split('T').first),
              _cell(font, session.cardTitle),
              _cell(font, _compact(session.practiceItems)),
              _cell(font, '${session.successRate}%'),
            ])),
      ],
    );
  }

  pw.Widget _cell(pw.Font font, String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10.5,
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
        pw.Text('توقيع الأخصائي: $specialistSignature',
            style: pw.TextStyle(font: font, fontSize: 14)),
        pw.Text('توقيع المدير: $managerSignature',
            style: pw.TextStyle(font: font, fontSize: 14)),
      ],
    );
  }

  pw.Widget _reportFooter(pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18),
      child: pw.Center(
        child: pw.Text(
          'تم إنشاء التقرير بواسطة منصة سند لإدارة الجلسات والبرامج العلاجية',
          style:
              pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    );
  }

  int _improvementRate(List<Evaluation> evaluations) {
    if (evaluations.isEmpty) return 0;
    final good = evaluations
        .where((item) => item.score == 'ناجح' || item.score == 'صحيح')
        .length;
    final partial = evaluations.where((item) => item.score == 'جزئي').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
  }

  int _sessionAverage(List<TherapySession> sessions) {
    if (sessions.isEmpty) return 0;
    final total =
        sessions.fold<int>(0, (sum, session) => sum + session.successRate);
    return (total / sessions.length).round();
  }

  String _compact(String text) {
    final cleaned = text.trimLeft().startsWith('{') ? '' : text.trim();
    if (cleaned.isEmpty) {
      return 'أنشطة علاجية مسجلة';
    }
    return cleaned.length > 90 ? '${cleaned.substring(0, 90)}...' : cleaned;
  }

  String _today() => DateTime.now().toIso8601String().split('T').first;
}
