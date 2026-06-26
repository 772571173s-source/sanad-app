import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../repositories/sanad_repository.dart';
import '../services/database_service.dart';
import '../services/demo_data_service.dart';

const demoPassDisplay = 'Demo@123456';

class DemoCenterScreen extends StatefulWidget {
  const DemoCenterScreen({super.key});

  @override
  State<DemoCenterScreen> createState() => _DemoCenterScreenState();
}

class _DemoCenterScreenState extends State<DemoCenterScreen> {
  final _service = DemoDataService(SanadRepository(DatabaseService.instance));
  Map<String, dynamic> _status = {};
  bool _loadingStatus = true;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  String? _selectedStudentId;
  List<Map<String, dynamic>> _demoStudents = [];
  List<Map<String, dynamic>> _demoUsers = [];
  List<Map<String, dynamic>> _demoPrograms = [];
  List<Map<String, dynamic>> _demoSpecialists = [];
  String? _selectedProgramId;
  String? _selectedSpecialistId;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loadingStatus = true);
    try {
      _status = await _service.getFullStatus();
      if (_status['exists'] == true) {
        _demoStudents = await _service.getDemoStudents();
        _demoUsers = await _service.getDemoUsers();
        _demoPrograms = await _service.getDemoPrograms();
        _demoSpecialists = await _service.getDemoSpecialists();
      } else {
        _demoStudents = [];
        _demoUsers = [];
        _demoPrograms = [];
        _demoSpecialists = [];
      }
    } catch (e) {
      _status = {'exists': false, 'error': '$e'};
    }
    if (mounted) setState(() => _loadingStatus = false);
  }

  void _showMsg(String msg, {bool error = false}) {
    setState(() {
      _message = msg;
      _messageIsError = error;
    });
  }

  Future<void> _seed() async {
    final libraryReady = await _service.isLibraryReady();
    if (!libraryReady) {
      _showMsg('مكتبة سند العلاجية غير جاهزة. تأكد من تهيئة النظام أولاً.', error: true);
      return;
    }
    setState(() => _busy = true);
    _showMsg('جارٍ إنشاء المركز التجريبي...');
    try {
      await _service.seedFullDemoData();
      _showMsg('تم إنشاء المركز التجريبي بنجاح.');
      await _refreshStatus();
    } catch (e) {
      _showMsg('خطأ: $e', error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final confirm = await _confirmDialog(
      'إعادة ضبط المركز التجريبي',
      'سيتم حذف الطلاب والجلسات والتقارير.\n'
      'سيبقى المركز والحسابات والمكتبة.\n'
      'لن تتأثر أي بيانات حقيقية.\n'
      'هل تريد المتابعة؟',
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    _showMsg('جارٍ إعادة ضبط المركز التجريبي...');
    try {
      await _service.resetDemoData();
      _showMsg('تم إعادة ضبط المركز التجريبي.');
      await _refreshStatus();
    } catch (e) {
      _showMsg('خطأ: $e', error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await _confirmDialog(
      'حذف المركز التجريبي',
      'سيتم حذف المركز والحسابات والمكتبة وكل البيانات التجريبية.\n'
      'لن تتأثر أي بيانات حقيقية.\n'
      'هل تريد المتابعة؟',
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    _showMsg('جارٍ حذف المركز التجريبي...');
    try {
      await _service.deleteDemoData();
      _showMsg('تم حذف المركز التجريبي.');
      await _refreshStatus();
    } catch (e) {
      _showMsg('خطأ: $e', error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runTool(String toolName) async {
    if (_selectedStudentId == null) {
      _showMsg('اختر طالبًا أولاً من قائمة الطلاب.', error: true);
      return;
    }
    if (_selectedProgramId == null || _selectedSpecialistId == null) {
      _showMsg('اختر البرنامج والأخصائي أولاً.', error: true);
      return;
    }
    setState(() => _busy = true);
    _showMsg('جارٍ تنفيذ الأداة: $toolName...');
    try {
      final progId = _selectedProgramId!;
      final specId = _selectedSpecialistId!;
      switch (toolName) {
        case 'prepareInitial':
          await _service.prepareInitialReport(_selectedStudentId!, progId, specId);
          _showMsg('تم تجهيز بيانات التقرير الأولي. ادخل كأخصائي وافتتح التقارير.');
          break;
        case 'addProgressSessions':
          await _service.addProgressSessions(_selectedStudentId!, progId, specId);
          _showMsg('تمت إضافة 5 جلسات تقدم.');
          break;
        case 'prepareFollowupNoChange':
          await _service.prepareFollowupNoChange(_selectedStudentId!, progId, specId);
          _showMsg('تم تجهيز متابعة بلا تغيير. ادخل كأخصائي وجرب تقرير متابعة.');
          break;
        case 'prepareFollowupWithProgress':
          await _service.prepareFollowupWithProgress(_selectedStudentId!, progId, specId);
          _showMsg('تم تجهيز متابعة مع تحسن. ادخل كأخصائي وجرب تقرير متابعة.');
          break;
        case 'prepareQuarterly':
          await _service.prepareQuarterlyData(_selectedStudentId!, progId, specId);
          _showMsg('تم تجهيز بيانات Q1/Q2. ادخل كمشرف فني وجرب التقارير الربعية.');
          break;
      }
      await _refreshStatus();
    } catch (e) {
      _showMsg('خطأ: $e', error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmDialog(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final exists = _status['exists'] == true;
    final inDemo = app.isDemoModeActive;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز سند التجريبي'),
          centerTitle: true,
        ),
        body: _loadingStatus
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshStatus,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ─── Message ─────────────────────────────
                    if (_message != null)
                      Card(
                        color: _messageIsError ? cs.errorContainer : cs.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(_messageIsError ? Icons.error_outline : Icons.check_circle_outline,
                                color: _messageIsError ? cs.error : cs.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_message!)),
                          ]),
                        ),
                      ),
                    if (_message != null) const SizedBox(height: 12),

                    // ═══════════════════════════════════════════
                    // SECTION 1: حالة المركز التجريبي
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'القسم 1: حالة المركز التجريبي', cs: cs),
                    const SizedBox(height: 8),
                    if (!exists)
                      Card(
                        color: cs.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            Icon(Icons.science_outlined, size: 48, color: cs.tertiary),
                            const SizedBox(height: 12),
                            Text('لم يتم إنشاء المركز التجريبي بعد',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('أنشئ المركز التجريبي من القسم 2 للبدء.',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                          ]),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            _StatusRow(icon: Icons.check_circle, iconColor: Colors.green,
                                label: 'المركز', value: _status['centerName'] ?? 'نشط', cs: cs),
                            _StatusRow(icon: Icons.local_library, iconColor: Colors.amber,
                                label: 'مكتبة سند', value: _status['libraryReady'] == true ? 'جاهزة' : 'غير جاهزة', cs: cs),
                            _StatusRow(icon: Icons.people, iconColor: Colors.blue,
                                label: 'الحسابات', value: '${_status['userCount'] ?? 0}', cs: cs),
                            _StatusRow(icon: Icons.schema_outlined, iconColor: Colors.indigo,
                                label: 'البرامج (مكتبة سند)', value: '${_status['programCount'] ?? 0}', cs: cs),
                            _StatusRow(icon: Icons.school, iconColor: Colors.green,
                                label: 'الطلاب (الذين أضفتهم)', value: '${_status['studentCount'] ?? 0}', cs: cs),
                            _StatusRow(icon: Icons.assessment_outlined, iconColor: Colors.orange,
                                label: 'التقييمات', value: '${_status['assessmentCount'] ?? 0}', cs: cs),
                            _StatusRow(icon: Icons.timer, iconColor: Colors.orange,
                                label: 'الجلسات', value: '${_status['sessionCount'] ?? 0}', cs: cs),
                            _StatusRow(icon: Icons.picture_as_pdf, iconColor: Colors.red,
                                label: 'التقارير', value: '${_status['reportCount'] ?? 0}', cs: cs),
                            _StatusRow(icon: Icons.flag_outlined, iconColor: Colors.teal,
                                label: 'الأهداف', value: '${_status['planCount'] ?? 0}', cs: cs),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ═══════════════════════════════════════════
                    // SECTION 2: إنشاء وتجهيز
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'القسم 2: إنشاء وتجهيز', cs: cs),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          if (!exists)
                            _ToolButton(
                              icon: Icons.add_circle_outline,
                              title: 'إنشاء مركز سند التجريبي',
                              subtitle: 'ينشئ المركز + حسابات الأدوار (يستخدم مكتبة سند العامة)',
                              busy: _busy,
                              color: cs.primary,
                              onTap: _seed,
                            ),
                          if (exists) ...[
                            const Divider(height: 24),
                            _ToolButton(
                              icon: Icons.restart_alt,
                              title: 'إعادة ضبط المركز التجريبي',
                              subtitle: 'يحذف الطلاب والجلسات والتقارير، ويبقي الحسابات',
                              busy: _busy,
                              color: Colors.orange,
                              onTap: _reset,
                            ),
                            const Divider(height: 24),
                            _ToolButton(
                              icon: Icons.delete_forever_outlined,
                              title: 'حذف المركز التجريبي بالكامل',
                              subtitle: 'يحذف كل شيء تجريبي دون تأثير على البيانات الحقيقية',
                              busy: _busy,
                              color: Colors.red,
                              onTap: _delete,
                            ),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ═══════════════════════════════════════════
                    // SECTION 3: التنقل السريع بين الأدوار
                    // ═══════════════════════════════════════════
                    Row(children: [
                      Expanded(child: _SectionHeader(title: 'القسم 3: التنقل السريع بين الأدوار', cs: cs)),
                      if (exists)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'تحديث القائمة',
                          onPressed: _busy ? null : _refreshStatus,
                        ),
                    ]),
                    const SizedBox(height: 8),
                    if (!exists)
                      Card(
                        color: cs.surfaceContainerHighest,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('أنشئ المركز التجريبي أولاً لتفعيل الأدوار.'),
                        ),
                      )
                    else if (_demoUsers.isEmpty)
                      Card(
                        color: cs.surfaceContainerHighest,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('لا توجد حسابات بعد. أضف مستخدمين من دور مدير المركز.'),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            Text('اختر دورًا للدخول به مباشرة. سيتم نقلك لواجهة النظام الحقيقية.',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(height: 12),
                            ..._roleEntries().map((role) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _RoleRow(
                                name: role.name,
                                icon: role.icon,
                                iconBg: role.iconBg,
                                isActive: app.isDemoModeActive && app.demoModeUserId == role.id,
                                onTap: inDemo
                                    ? (app.demoModeUserId == role.id ? null : () => _enterRole(app, role.id))
                                    : () => _enterRole(app, role.id),
                              ),
                            )),
                            if (inDemo) ...[
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: () => app.exitDemoMode(),
                                icon: const Icon(Icons.exit_to_app),
                                label: const Text('العودة إلى حساب مالك سند'),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ═══════════════════════════════════════════
                    // SECTION 4: أدوات تسريع التجربة
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'القسم 4: أدوات تسريع التجربة', cs: cs),
                    const SizedBox(height: 8),
                    if (!exists)
                      Card(
                        color: cs.surfaceContainerHighest,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('أنشئ المركز التجريبي أولاً.'),
                        ),
                      )
                    else if (_demoStudents.isEmpty)
                      Card(
                        color: cs.tertiaryContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('لا يوجد طلاب بعد. أضف طالبًا من دور مدخل البيانات أو منسق أولاً.'),
                        ),
                      )
                    else if (_demoPrograms.isEmpty)
                      Card(
                        color: cs.tertiaryContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('مكتبة سند العلاجية غير متوفرة. تأكد من تهيئة النظام.'),
                        ),
                      )
                    else if (_demoSpecialists.isEmpty)
                      Card(
                        color: cs.tertiaryContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('لا يوجد أخصائيون بعد. أضف أخصائيًا من دور مدير المركز أولاً.'),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('اختر طالبًا + برنامج + أخصائي ثم أداة تسريع:',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedStudentId,
                                decoration: const InputDecoration(labelText: 'الطالب', border: OutlineInputBorder()),
                                items: _demoStudents.map((s) => DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text('${s['name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) => setState(() => _selectedStudentId = v),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _selectedProgramId,
                                decoration: const InputDecoration(labelText: 'البرنامج العلاجي', border: OutlineInputBorder()),
                                items: _demoPrograms.map((p) => DropdownMenuItem(
                                  value: p['id'] as String,
                                  child: Text('${p['name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) => setState(() => _selectedProgramId = v),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _selectedSpecialistId,
                                decoration: const InputDecoration(labelText: 'الأخصائي', border: OutlineInputBorder()),
                                items: _demoSpecialists.map((s) => DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text('${s['name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) => setState(() => _selectedSpecialistId = v),
                              ),
                              const SizedBox(height: 16),
                              _ToolButton(
                                icon: Icons.assignment_turned_in_outlined,
                                title: 'تجهيز تقرير أولي',
                                subtitle: 'ينشئ تقييم + أهداف + خطوات مهارية للطالب المختار',
                                busy: _busy, color: Colors.green,
                                onTap: () => _runTool('prepareInitial'),
                              ),
                              const Divider(height: 20),
                              _ToolButton(
                                icon: Icons.add_circle_outline,
                                title: 'إضافة 5 جلسات تقدم',
                                subtitle: 'يضيف 5 جلسات بتواريخ مختلفة ورفع تدريجي في progress',
                                busy: _busy, color: Colors.blue,
                                onTap: () => _runTool('addProgressSessions'),
                              ),
                              const Divider(height: 20),
                              _ToolButton(
                                icon: Icons.timeline_outlined,
                                title: 'تجهيز متابعة بلا تغيير',
                                subtitle: 'ينشئ تقرير سابق + جلسات قبله ولا يضيف جلسات بعده',
                                busy: _busy, color: Colors.orange,
                                onTap: () => _runTool('prepareFollowupNoChange'),
                              ),
                              const Divider(height: 20),
                              _ToolButton(
                                icon: Icons.trending_up,
                                title: 'تجهيز متابعة مع تحسن',
                                subtitle: 'ينشئ تقرير سابق + جلسات بعده مع تحسن في النتائج',
                                busy: _busy, color: Colors.teal,
                                onTap: () => _runTool('prepareFollowupWithProgress'),
                              ),
                              const Divider(height: 20),
                              _ToolButton(
                                icon: Icons.calendar_month_outlined,
                                title: 'تجهيز بيانات ربع سنوية Q1/Q2',
                                subtitle: 'ينشئ جلسات Q1 + تقرير Q1 + جلسات Q2 مع تقدم',
                                busy: _busy, color: Colors.purple,
                                onTap: () => _runTool('prepareQuarterly'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  void _enterRole(AppProvider app, String userId) async {
    try {
      await app.enterDemoMode(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم التبديل إلى ${app.user?.name ?? 'الدور'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<_RoleEntry> _roleEntries() {
    return [
      for (final u in _demoUsers)
        _RoleEntry(
          u['id'] as String,
          u['name'] as String? ?? 'مستخدم',
          _roleIcon(u['role'] as String? ?? ''),
          _roleColor(u['role'] as String? ?? ''),
        ),
    ];
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'centerManager': return Icons.business;
      case 'clinicalSupervisor': return Icons.medical_services_outlined;
      case 'coordinator': return Icons.assignment_ind;
      case 'dataEntry': return Icons.drive_file_rename_outline;
      case 'therapyProgramEntry': return Icons.schema_outlined;
      case 'specialist': return Icons.hearing;
      case 'parent': return Icons.family_restroom;
      default: return Icons.person;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'centerManager': return Colors.blue;
      case 'clinicalSupervisor': return Colors.teal;
      case 'coordinator': return Colors.cyan;
      case 'dataEntry': return Colors.brown;
      case 'therapyProgramEntry': return Colors.indigo;
      case 'specialist': return Colors.green;
      case 'parent': return Colors.pink;
      default: return Colors.grey;
    }
  }
}

// ─── Shared Widgets ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  const _SectionHeader({required this.title, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: cs.primary)),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final ColorScheme cs;
  const _StatusRow({required this.icon, required this.iconColor, required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: iconColor)),
      ]),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final Color color;
  final VoidCallback onTap;
  const _ToolButton({required this.icon, required this.title, required this.subtitle, required this.busy, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: busy ? null : onTap,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(8)),
          child: busy
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        )),
        if (!busy) Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
      ]),
    );
  }
}

class _RoleEntry {
  final String id;
  final String name;
  final IconData icon;
  final Color iconBg;
  const _RoleEntry(this.id, this.name, this.icon, this.iconBg);
}

class _RoleRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconBg;
  final bool isActive;
  final VoidCallback? onTap;
  const _RoleRow({required this.name, required this.icon, required this.iconBg, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: isActive ? cs.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive ? BorderSide(color: cs.primary, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: iconBg.withValues(alpha: .2), child: Icon(icon, color: iconBg, size: 20)),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: isActive ? Text('نشط حاليًا', style: TextStyle(color: cs.primary, fontSize: 11)) : null,
        trailing: FilledButton(
          onPressed: isActive ? null : onTap,
          child: Text(isActive ? 'نشط' : 'الدخول'),
        ),
      ),
    );
  }
}
