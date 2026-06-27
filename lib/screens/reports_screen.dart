import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/report_export_service.dart';
import '../services/smart_pdf_report_service.dart';
import '../services/word_report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// Which step of the UI the user is on:
  /// 'studentSelect' → choose student (manager/supervisor)
  /// 'assignmentSelect' → choose assignment (specialist, after student picked)
  /// 'form' → show report form with save button
  String _step = 'studentSelect';

  /// For manager/supervisor roles: selected student
  Student? _selectedStudent;

  /// For manager/supervisor: available programs for the selected student
  List<TherapyProgramTemplate> _programsForStudent = [];

  // Common
  String scope = 'singleProgram';
  String? _selectedProgramId;
  final signature = TextEditingController(text: 'الأخصائي');
  final manager = TextEditingController(text: 'المدير');

  // Specialist fields (null = all assigned programs, a.id = specific program)
  String? _selectedAssignmentId;
  List<StudentProgramAssignment> _specialistAssignmentsList = [];

  // Manager/Supervisor: selected year for quarterly reports
  int _selectedYear = DateTime.now().year;

  // Loading state
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initStep();
  }

  void _initStep() {
    final app = context.read<AppProvider>();
    final user = app.user;
    if (user == null) return;

    if (app.isSpecialist) {
      _step = 'studentSelect';
      _specialistAssignmentsList = _fetchSpecialistAssignments(app);
      if (_specialistAssignmentsList.isEmpty) {
        _step = 'studentSelect';
      }
    } else if (app.isParent) {
      _step = 'studentSelect';
    } else {
      // Manager/supervisor/owner: show student selector
      _step = 'studentSelect';
    }
  }

  @override
  void dispose() {
    signature.dispose();
    manager.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data helpers
  // ---------------------------------------------------------------------------

  List<StudentProgramAssignment> _fetchSpecialistAssignments(AppProvider app) {
    final user = app.user;
    if (user == null) return [];
    return app.studentProgramAssignments
        .where((a) =>
            a.specialistId == user.id &&
            a.isActive &&
            a.centerId == app.activeCenterId)
        .toList();
  }

  Set<String> _specialistStudentIds(AppProvider app) {
    return _fetchSpecialistAssignments(app)
        .map((a) => a.studentId)
        .toSet();
  }

  List<Student> _availableStudents(AppProvider app) {
    if (app.isSpecialist) {
      final ids = _specialistStudentIds(app);
      return app.students.where((s) => ids.contains(s.id)).toList();
    }
    // Manager/supervisor/owner: all students
    return app.students;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    if (user == null) {
      return const Center(child: Text('يجب تسجيل الدخول أولاً.'));
    }

    String title;
    if (_step == 'studentSelect') {
      if (app.isSpecialist) {
        title = 'اختر الإسناد';
      } else {
        title = 'اختر الطالب';
      }
    } else {
      title = 'التقارير الذكية';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step != 'studentSelect') {
              setState(() {
                _step = 'studentSelect';
                _selectedStudent = null;
                _selectedAssignmentId = null;
                _selectedProgramId = null;
              });
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step == 'studentSelect')
                  _buildStudentSelectionStep(app)
                else
                  _buildFormStep(app),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Student / assignment selection
  // ---------------------------------------------------------------------------

  Widget _buildStudentSelectionStep(AppProvider app) {
    final user = app.user;
    if (user == null) return const SizedBox.shrink();

    if (app.isSpecialist) {
      return _buildSpecialistAssignmentPicker(app);
    }

    return _buildStudentPicker(app);
  }

  Widget _buildStudentPicker(AppProvider app) {
    final students = _availableStudents(app);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اختر الطالب',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (students.isEmpty)
          const Text('لا يوجد طلاب.')
        else
          ...students.map((student) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StudentTile(
                  student: student,
                  onTap: () => _selectStudentAndProceed(app, student),
                ),
              )),
      ],
    );
  }

  Future<void> _selectStudentAndProceed(AppProvider app, Student student) async {
    // Load the student's full data so the report builder has access
    try {
      await app.selectStudent(student);
    } catch (_) {
      // proceed even if data load partially fails
    }
    final studentProgIds = app.studentProgramAssignments
        .where((a) =>
            a.studentId == student.id &&
            a.isActive &&
            a.centerId == app.activeCenterId)
        .map((a) => a.programId)
        .toSet();
    setState(() {
      _selectedStudent = student;
      _programsForStudent = app.therapyPrograms
          .where((p) => studentProgIds.contains(p.id))
          .toList();
      _step = 'form';
    });
  }

  Widget _buildSpecialistAssignmentPicker(AppProvider app) {
    final assignments = _fetchSpecialistAssignments(app);
    final studentIds = assignments.map((a) => a.studentId).toSet();
    final students = app.students.where((s) => studentIds.contains(s.id)).toList();

    if (assignments.isEmpty) {
      return const Text('لا توجد إسنادات نشطة.');
    }

    // Group assignments by student
    final groups = <String, List<StudentProgramAssignment>>{};
    for (final a in assignments) {
      groups.putIfAbsent(a.studentId, () => []);
      groups[a.studentId]!.add(a);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إسناداتي النشطة',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...groups.entries.map((entry) {
          final student = students.where((s) => s.id == entry.key).firstOrNull;
          final studentName = student?.name ?? entry.key;
          final programAssignments = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...programAssignments.map((a) {
                    final program = app.therapyPrograms
                        .where((p) => p.id == a.programId)
                        .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () => _selectAssignment(app, a, student),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.auto_stories_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                program?.name ?? 'برنامج',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_back_ios_new, size: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (programAssignments.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        onPressed: () => _selectAllAssignments(
                            app, entry.value, student),
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text('جميع برامجي المسندة لهذا الطالب'),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _selectAssignment(
      AppProvider app, StudentProgramAssignment assignment, Student? student) {
    if (student != null) {
      app.selectStudent(student).catchError((_) {});
    }
    setState(() {
      _selectedStudent = student;
      _selectedAssignmentId = assignment.id;
      _programsForStudent = app.therapyPrograms
          .where((p) => p.id == assignment.programId)
          .toList();
      _step = 'form';
    });
  }

  void _selectAllAssignments(
      AppProvider app, List<StudentProgramAssignment> assignments, Student? student) {
    if (student != null) {
      app.selectStudent(student).catchError((_) {});
    }
    setState(() {
      _selectedStudent = student;
      _selectedAssignmentId = null; // null = all assigned
      final programIds = assignments.map((a) => a.programId).toSet();
      _programsForStudent = app.therapyPrograms
          .where((p) => programIds.contains(p.id))
          .toList();
      _step = 'form';
    });
  }

  // ---------------------------------------------------------------------------
  // Step 2: Report form
  // ---------------------------------------------------------------------------

  Widget _buildFormStep(AppProvider app) {
    final student = _selectedStudent;
    if (student == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormStudentInfo(app, student),
        const SizedBox(height: 16),
        if (app.isSpecialist)
          _buildFormSpecialist(app, student)
        else
          _buildFormManager(app, student),
        const SizedBox(height: 16),
        _buildPreviousReports(app),
      ],
    );
  }

  Widget _buildFormStudentInfo(AppProvider app, Student student) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الطالب: ${student.name}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          if (_programsForStudent.isNotEmpty)
            Text(
                'البرامج: ${_programsForStudent.map((p) => p.name).join('، ')}',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Specialist form
  // ---------------------------------------------------------------------------

  Widget _buildFormSpecialist(AppProvider app, Student student) {
    final assignments = _fetchSpecialistAssignments(app)
        .where((a) => a.studentId == student.id)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إنشاء تقرير علاجي شامل',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (assignments.length > 1) ...[
          _buildFormAssignmentDropdown(assignments, app),
          const SizedBox(height: 12),
        ],
        if (assignments.isNotEmpty) ...[
          TextField(
            controller: signature,
            decoration: InputDecoration(
              labelText: 'توقيع الأخصائي (اختياري)',
              hintText: app.user?.name ?? 'الأخصائي',
            ),
          ),
          const SizedBox(height: 16),
          _buildSaveButton(app, student),
          const SizedBox(height: 8),
          Text(
            'التقرير يشمل جميع الأوقات وجميع البيانات المتاحة للبرنامج المحدد.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormAssignmentDropdown(
      List<StudentProgramAssignment> assignments, AppProvider app) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedAssignmentId,
      decoration: const InputDecoration(labelText: 'اختر البرنامج'),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('جميع برامجي المسندة'),
        ),
        ...assignments.map((a) {
          final program = app.therapyPrograms
              .where((p) => p.id == a.programId)
              .firstOrNull;
          return DropdownMenuItem(
            value: a.id,
            child: Text(program?.name ?? 'برنامج'),
          );
        }),
      ],
      onChanged: (value) => setState(() {
        _selectedAssignmentId = value;
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Manager form
  // ---------------------------------------------------------------------------

  Widget _buildFormManager(AppProvider app, Student student) {
    final programs = _programsForStudent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إنشاء تقرير علاجي',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        // Scope selection
        Wrap(
          spacing: 4,
          children: [
            SizedBox(
              width: 160,
              child: RadioListTile<String>(
                title:
                    const Text('جميع البرامج', style: TextStyle(fontSize: 13)),
                value: 'allPrograms',
                groupValue: scope,
                onChanged: (v) => setState(() => scope = v!),
                dense: true,
              ),
            ),
            SizedBox(
              width: 160,
              child: RadioListTile<String>(
                title:
                    const Text('برنامج محدد', style: TextStyle(fontSize: 13)),
                value: 'singleProgram',
                groupValue: scope,
                onChanged: (v) => setState(() => scope = v!),
                dense: true,
              ),
            ),
          ],
        ),
        if (scope == 'singleProgram' && programs.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedProgramId,
            decoration: const InputDecoration(labelText: 'اختر البرنامج'),
            items: programs
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedProgramId = value),
          ),
        ],
        const SizedBox(height: 16),
        // Year selector for quarterly reports
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('السنة:',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () =>
                  setState(() => _selectedYear = _selectedYear - 1),
            ),
            Text('$_selectedYear',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () =>
                  setState(() => _selectedYear = _selectedYear + 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Action buttons
        Text('اختر نوع التقرير:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildActionButton('تقرير شامل', Icons.description,
                _isSaving ? null : () => _generateComprehensiveReport(app, student),
                isFilled: true),
            _buildActionButton('الربع الأول', Icons.looks_one,
                _isSaving ? null : () => _generateQuarterlyReport(app, student, 'Q1')),
            _buildActionButton('الربع الثاني', Icons.looks_two,
                _isSaving ? null : () => _generateQuarterlyReport(app, student, 'Q2')),
            _buildActionButton('الربع الثالث', Icons.looks_3,
                _isSaving ? null : () => _generateQuarterlyReport(app, student, 'Q3')),
            _buildActionButton('الربع الرابع', Icons.looks_4,
                _isSaving ? null : () => _generateQuarterlyReport(app, student, 'Q4')),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: signature,
          decoration: const InputDecoration(labelText: 'توقيع الأخصائي'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: manager,
          decoration: const InputDecoration(labelText: 'توقيع المدير'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text('Word DOCX (تجريبي - PoC)',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildActionButton('تصدير Word تجريبي', Icons.description_outlined,
            _isSaving ? null : () => _generateWordPoC()),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onPressed,
      {bool isFilled = false}) {
    final style = isFilled
        ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          );
    final widget = isFilled ? FilledButton.icon : OutlinedButton.icon;
    return widget(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: style,
    );
  }

  // ---------------------------------------------------------------------------
  // Previous reports
  // ---------------------------------------------------------------------------

  Widget _buildPreviousReports(AppProvider app) {
    final student = _selectedStudent;
    final matchingReports = student == null
        ? app.reports
        : app.reports.where((r) => r.studentId == student.id).toList();

    if (matchingReports.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('التقارير السابقة',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...matchingReports.take(5).map((report) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(
                  report.reportTitle.isNotEmpty
                      ? report.reportTitle
                      : report.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${report.scope == 'singleProgram' ? 'برنامج محدد' : report.scope == 'allPrograms' ? 'جميع البرامج' : report.scope} - ${report.createdAt.split('T').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: Text('${report.improvementRate}%'),
            )),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Save buttons
  // ---------------------------------------------------------------------------

  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Widget _buildSaveButton(AppProvider app, Student student) {
    final onMobile = _isMobile;
    return FilledButton.icon(
      onPressed:
          _isSaving ? null : () => _generateSpecialistReport(app, student),
      icon: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(onMobile ? Icons.share_outlined : Icons.save_alt_outlined),
      label: Text(_isSaving
          ? 'جارٍ حفظ التقرير...'
          : onMobile
              ? 'مشاركة تقرير PDF'
              : 'حفظ تقرير PDF شامل'),
    );
  }

  // ---------------------------------------------------------------------------
  // Report generation
  // ---------------------------------------------------------------------------

  Future<void> _generateComprehensiveReport(
      AppProvider app, Student student) async {
    String? programId;
    if (scope == 'singleProgram') {
      programId = _selectedProgramId;
    }

    await _performSave(
      context: context,
      app: app,
      studentId: student.id,
      type: 'تقرير شامل',
      scope: scope,
      programId: programId,
      specialistId: null,
      dateFrom: null,
      dateTo: null,
      specialistSignature: signature.text.trim(),
      managerSignature: manager.text.trim(),
      reportCategory: 'general',
    );
  }

  Future<void> _generateQuarterlyReport(
      AppProvider app, Student student, String quarter) async {
    final y = _selectedYear;
    final start = AppProvider.quarterStart(quarter, y);
    final end = AppProvider.quarterEnd(quarter, y);
    final dateFrom = start.toIso8601String().split('T').first;
    final dateTo = end.toIso8601String().split('T').first;

    String? programId;
    if (scope == 'singleProgram') {
      programId = _selectedProgramId;
    }

    final prev = app.findPreviousQuarterlyReport(
      studentId: student.id,
      scope: scope,
      programId: programId,
      quarter: quarter,
      year: y.toString(),
    );

    await _performSave(
      context: context,
      app: app,
      studentId: student.id,
      type: 'تقرير ربع سنوي',
      scope: scope,
      programId: programId,
      specialistId: null,
      dateFrom: dateFrom,
      dateTo: dateTo,
      specialistSignature: signature.text.trim(),
      managerSignature: manager.text.trim(),
      reportCategory: 'supervisorQuarterly',
      previousReportId: prev?.id,
      quarter: quarter,
      year: y.toString(),
    );
  }

  Future<void> _generateSpecialistReport(
      AppProvider app, Student student) async {
    developer.log('specialist report start', name: 'SmartReport');
    developer.log('selectedStudentId: ${student.id}', name: 'SmartReport');
    developer.log(
        'selectedAssignmentId: $_selectedAssignmentId', name: 'SmartReport');

    final specialistSig = signature.text.trim().isNotEmpty
        ? signature.text.trim()
        : (app.user?.name ?? '');

    String? programId;
    String resolvedScope;
    if (_selectedAssignmentId == null) {
      resolvedScope = 'specialistPrograms';
      programId = null;
    } else {
      final assignments = _fetchSpecialistAssignments(app)
          .where((a) => a.studentId == student.id);
      final assignment = assignments
          .where((a) => a.id == _selectedAssignmentId)
          .firstOrNull;
      programId = assignment?.programId;
      resolvedScope = 'singleProgram';
    }

    // Determine report category and find previous report
    final prevReport = app.findPreviousSpecialistReport(
      studentId: student.id,
      programId: programId,
      specialistId: app.user?.id,
      scope: resolvedScope,
    );
    final reportCategory = prevReport == null
        ? 'specialistInitial'
        : 'specialistFollowup';

    await _performSave(
      context: context,
      app: app,
      studentId: student.id,
      type: 'تقرير شامل',
      scope: resolvedScope,
      programId: programId,
      specialistId: app.user?.id,
      dateFrom: null,
      dateTo: null,
      specialistSignature: specialistSig,
      managerSignature: '',
      reportCategory: reportCategory,
      previousReportId: prevReport?.id,
    );
  }

  Future<void> _generateWordPoC() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final path = await WordReportService.generateTestDocx();
      if (path == null) {
        _showSnack('تم إلغاء حفظ الملف.');
        return;
      }
      _showSnack('تم حفظ ملف Word: $path');
    } catch (e) {
      _showSnack('خطأ: ${e.toString().replaceFirst('Bad state: ', '')}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _performSave({
    required BuildContext context,
    required AppProvider app,
    required String studentId,
    required String type,
    required String scope,
    String? programId,
    String? specialistId,
    String? dateFrom,
    String? dateTo,
    String specialistSignature = '',
    String managerSignature = '',
    String? mockOutputPath,
    String reportCategory = 'general',
    String? previousReportId,
    String? quarter,
    String? year,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      developer.log('Step 1: buildSmartReportData', name: 'SmartReport');
      developer.log(
          '  studentId=$studentId scope=$scope programId=$programId specialistId=$specialistId',
          name: 'SmartReport');

      final (:data, :record, :comparison) = await app.buildSmartReportData(
        studentId: studentId,
        type: type,
        scope: scope,
        programId: programId,
        specialistId: specialistId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        specialistSignature: specialistSignature,
        managerSignature: managerSignature,
        reportCategory: reportCategory,
        previousReportId: previousReportId,
        quarter: quarter,
        year: year,
      );
      developer.log('  sections=${data.sections.length}', name: 'SmartReport');

      if (data.sections.isEmpty) {
        _showSnack('التقرير لا يحتوي على بيانات.');
        return;
      }

      developer.log('Step 2: buildSmartReportPdfBytes', name: 'SmartReport');
      final service = SmartPdfReportService();
      final isDemoCenter = data.center?.id == 'demo_center_sanad' ||
          data.student.id.startsWith('demo_');
      final bytes = await service.buildSmartReportPdfBytes(
        data,
        specialistSignature: specialistSignature,
        managerSignature: managerSignature,
        reportCategory: reportCategory,
        comparison: comparison,
        quarter: quarter,
        year: year,
        isDemo: isDemoCenter,
      );
      developer.log('  bytes.length=${bytes.length}', name: 'SmartReport');

      if (bytes.isEmpty) {
        _showSnack('فشل إنشاء ملف PDF: الملف الناتج فارغ.');
        return;
      }

      developer.log('Step 3: export by platform', name: 'SmartReport');
      final fileName = ReportExportService.buildFileName(
        studentName: data.student.name,
        programName: data.sections.length == 1
            ? data.sections.first.programName
            : null,
      );

      String? outputPath;
      if (mockOutputPath != null) {
        outputPath = mockOutputPath;
        await File(outputPath).writeAsBytes(bytes);
      } else {
        outputPath = await ReportExportService.exportPdf(
          pdfBytes: bytes,
          fileName: fileName,
        );
      }

      if (outputPath == null) {
        if (_isMobile) {
          _showSnack('تعذر فتح نافذة المشاركة.');
        } else {
          _showSnack('تم إلغاء حفظ التقرير.');
        }
        return;
      }
      developer.log('  outputPath=$outputPath', name: 'SmartReport');

      developer.log('Step 4: save ReportRecord', name: 'SmartReport');
      final savedRecord = record.copyWith(
        filePath: outputPath,
        reportStatus: 'exported',
      );
      await app.saveReportRecord(savedRecord);
      developer.log('  ReportRecord saved', name: 'SmartReport');

      if (_isMobile) {
        _showSnack('تم فتح نافذة المشاركة.');
      } else {
        _showSnack('تم حفظ التقرير بنجاح.');
      }
    } catch (e, stack) {
      developer.log('ERROR in _performSave: $e', name: 'SmartReport');
      developer.log('stack: $stack', name: 'SmartReport');
      _showSnack('حدث خطأ: ${e.toString().replaceFirst('Bad state: ', '')}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ---------------------------------------------------------------------------
// Student tile widget
// ---------------------------------------------------------------------------

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.onTap,
  });

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.child_care_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  if (student.diagnosis.isNotEmpty)
                    Text(student.diagnosis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_back_ios_new, size: 16, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
    );
  }
}
