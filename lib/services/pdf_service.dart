import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';

class PdfService {
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
                pw.Text('سند - بيانات دخول ولي الأمر',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 18),
                pw.Text('الطالب: ${student.name}',
                    style: pw.TextStyle(font: font, fontSize: 16)),
                pw.SizedBox(height: 12),
                _credentialRow(
                    font: font, label: 'البريد', value: student.portalEmail),
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
    final improvement = _improvementRate(evaluations);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(center?.name ?? 'مركز سند',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(center?.address ?? '',
                      style: pw.TextStyle(font: font)),
                  pw.Text(center?.phone ?? '', style: pw.TextStyle(font: font)),
                ],
              ),
              pw.Container(
                width: 78,
                height: 78,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.teal),
                    borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text('سند',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.Divider(),
          pw.Text('تقرير سند - $type',
              style: pw.TextStyle(
                  font: font, fontSize: 26, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('الطالب: ${student.name}', style: pw.TextStyle(font: font)),
          pw.Text('العمر: ${student.age}', style: pw.TextStyle(font: font)),
          pw.Text('التشخيص: ${student.diagnosis}',
              style: pw.TextStyle(font: font)),
          pw.Text('نسبة التحسن: $improvement%',
              style: pw.TextStyle(
                  font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text('الخطة التدريبية',
              style: pw.TextStyle(
                  font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (plans.isEmpty)
            pw.Text('لا توجد أهداف مسجلة.', style: pw.TextStyle(font: font)),
          ...plans.map((plan) => pw.Bullet(
              text: '${plan.goal} - تقدم ${plan.progress}%',
              style: pw.TextStyle(font: font))),
          pw.SizedBox(height: 16),
          pw.Text('الجلسات',
              style: pw.TextStyle(
                  font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (sessions.isEmpty)
            pw.Text('لا توجد جلسات مسجلة.', style: pw.TextStyle(font: font)),
          ...sessions.take(12).map((session) => pw.Bullet(
              text:
                  '${session.startedAt} - ${session.sessionType} - ${session.cardTitle} - ${session.quickResult} - نجاح ${session.successRate}% - ${session.practiceItems}',
              style: pw.TextStyle(font: font))),
          pw.SizedBox(height: 16),
          pw.Text('تقييم نطق الحروف',
              style: pw.TextStyle(
                  font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (evaluations.isEmpty)
            pw.Text('لا توجد تقييمات مسجلة.', style: pw.TextStyle(font: font)),
          ...evaluations.take(18).map((evaluation) => pw.Bullet(
              text:
                  '${evaluation.letter} - ${evaluation.position} - ${evaluation.errorType} - ${evaluation.score}',
              style: pw.TextStyle(font: font))),
          pw.SizedBox(height: 24),
          pw.Text('سجل التقارير السابقة داخل ملف الطالب: ${reports.length}',
              style: pw.TextStyle(font: font)),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('توقيع الأخصائي: $specialistSignature',
                  style: pw.TextStyle(font: font, fontSize: 16)),
              pw.Text('توقيع المدير: $managerSignature',
                  style: pw.TextStyle(font: font, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
        name: 'sanad-report-${student.id}.pdf', onLayout: (_) => pdf.save());
  }

  int _improvementRate(List<Evaluation> evaluations) {
    if (evaluations.isEmpty) return 0;
    final good = evaluations
        .where((item) => item.score == 'ناجح' || item.score == 'صحيح')
        .length;
    final partial = evaluations.where((item) => item.score == 'جزئي').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
  }
}
