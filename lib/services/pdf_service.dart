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
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(center?.phone ?? '',
                        style: pw.TextStyle(font: font)),
                  ),
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
          pw.Text('سجل التقارير داخل ملف الطالب: ${reports.length}',
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

  Future<void> printSessionReport({
    SanadCenter? center,
    required Student student,
    required String specialistName,
    required String programName,
    required String skillTitle,
    required List<ProgramActivity> activities,
    required Map<String, String> results,
    required int successRate,
    required int durationSeconds,
    required int homeworkSentCount,
    required String notes,
    required String specialistSignature,
    required String managerSignature,
  }) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final pdf = pw.Document();
    final date = DateTime.now().toIso8601String().split('T').first;
    final good = results.values
        .where((value) => value == 'صحيح' || value == 'جيد' || value == 'ناجح')
        .length;
    final partial = results.values
        .where((value) => value == 'جزئي' || value == 'بمساعدة')
        .length;
    final weak = results.values
        .where((value) => value == 'خطأ' || value == 'لا يؤدي')
        .length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => [
          _reportHeader(font, center, date),
          pw.SizedBox(height: 14),
          _sectionTitle(font, 'تقرير جلسة يومي'),
          pw.SizedBox(height: 10),
          _infoBox(font, [
            'الطالب: ${student.name}',
            'العمر: ${student.age}',
            'التشخيص: ${student.diagnosis}',
            'ولي الأمر: ${student.parentName}',
            'رقم ولي الأمر: ${student.parentPhone}',
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle(font, 'بيانات الجلسة'),
          _infoBox(font, [
            'البرنامج: $programName',
            'المهارة: $skillTitle',
            'الأخصائي: $specialistName',
            'مدة الجلسة: ${_formatDuration(durationSeconds)}',
            'نسبة النجاح: $successRate%',
            'الواجبات المرسلة: $homeworkSentCount',
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle(font, 'الأنشطة ونتائج التقييم'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell(font, 'النشاط', bold: true),
                  _cell(font, 'التقييم', bold: true),
                ],
              ),
              ...activities.map((activity) => pw.TableRow(children: [
                    _cell(font, activity.title),
                    _cell(font, results[activity.id] ?? 'غير مقيّم'),
                  ])),
            ],
          ),
          pw.SizedBox(height: 12),
          _sectionTitle(font, 'ملخص الأخصائي'),
          _infoBox(font, [
            'نقاط القوة: ${good > 0 ? 'استجابات صحيحة في $good نشاط.' : 'تحتاج إلى متابعة رصد نقاط القوة.'}',
            'نقاط الضعف: ${weak > 0 ? 'ظهرت صعوبة في $weak نشاط.' : 'لا توجد صعوبات بارزة في هذه الجلسة.'}',
            'التوصيات: ${partial + weak > 0 ? 'إعادة التدريب على الأنشطة الجزئية أو غير المؤداة مع تقليل المساعدة تدريجيًا.' : 'الانتقال التدريجي إلى مستوى أعلى مع تعزيز الأداء.'}',
            'خطة الجلسة القادمة: مراجعة قصيرة ثم إضافة نشاط واحد جديد مناسب للتقدم.',
            'ملاحظات إضافية: ${notes.isEmpty ? 'لا توجد ملاحظات إضافية.' : notes}',
          ]),
          pw.SizedBox(height: 26),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('توقيع الأخصائي: $specialistSignature',
                  style: pw.TextStyle(font: font, fontSize: 14)),
              pw.Text('توقيع المدير: $managerSignature',
                  style: pw.TextStyle(font: font, fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text('ختم المركز / الشعار لاحقًا',
                style: pw.TextStyle(font: font, color: PdfColors.grey600)),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
        name: 'sanad-session-${student.id}.pdf', onLayout: (_) => pdf.save());
  }

  pw.Widget _reportHeader(pw.Font font, SanadCenter? center, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(center?.name ?? 'مركز سند',
                style: pw.TextStyle(
                    font: font, fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text(center?.address ?? 'العنوان غير محدد',
                style: pw.TextStyle(font: font)),
            pw.Directionality(
              textDirection: pw.TextDirection.ltr,
              child: pw.Text(center?.phone ?? '',
                  style: pw.TextStyle(font: font),
                  textAlign: pw.TextAlign.left),
            ),
            pw.Text('تاريخ التقرير: $date', style: pw.TextStyle(font: font)),
          ],
        ),
        pw.Container(
          width: 76,
          height: 76,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.teal),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text('سند',
              style: pw.TextStyle(
                  font: font, fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(pw.Font font, String title) => pw.Text(title,
      style: pw.TextStyle(
          font: font, fontSize: 17, fontWeight: pw.FontWeight.bold));

  pw.Widget _infoBox(pw.Font font, List<String> lines) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: lines
              .map((line) => pw.Text(line, style: pw.TextStyle(font: font)))
              .toList(),
        ),
      );

  pw.Widget _cell(pw.Font font, String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            style: pw.TextStyle(
                font: font,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes دقيقة و $remaining ثانية';
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
