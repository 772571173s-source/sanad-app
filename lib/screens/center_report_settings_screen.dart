import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/center_report_settings.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class CenterReportSettingsScreen extends StatefulWidget {
  const CenterReportSettingsScreen({super.key});

  @override
  State<CenterReportSettingsScreen> createState() =>
      _CenterReportSettingsScreenState();
}

class _CenterReportSettingsScreenState
    extends State<CenterReportSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _arabicHeaderCtrl = TextEditingController();
  final _englishHeaderCtrl = TextEditingController();
  final _reportTitleCtrl = TextEditingController();
  final _supervisorNameCtrl = TextEditingController();
  final _footerNotesCtrl = TextEditingController();
  final _fundNameCtrl = TextEditingController();

  bool _reportsToFund = false;
  bool _showFundCardNumber = false;
  bool _showReferralDate = false;
  bool _showReferralSource = false;
  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _arabicHeaderCtrl.dispose();
    _englishHeaderCtrl.dispose();
    _reportTitleCtrl.dispose();
    _supervisorNameCtrl.dispose();
    _footerNotesCtrl.dispose();
    _fundNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await context.read<AppProvider>().loadCenterReportSettings();
    if (!mounted) return;
    final s = context.read<AppProvider>().centerReportSettings;
    if (s == null) return;
    setState(() {
      _arabicHeaderCtrl.text = s.arabicHeaderText;
      _englishHeaderCtrl.text = s.englishHeaderText;
      _reportTitleCtrl.text = s.defaultReportTitle;
      _supervisorNameCtrl.text = s.defaultTechnicalSupervisorName;
      _footerNotesCtrl.text = s.footerNotes;
      _fundNameCtrl.text = s.fundName;
      _reportsToFund = s.reportsToFund;
      _showFundCardNumber = s.showFundCardNumber;
      _showReferralDate = s.showReferralDate;
      _showReferralSource = s.showReferralSource;
      _loaded = true;
    });
  }

  String? _existingLogoBase64() =>
      context.read<AppProvider>().centerReportSettings?.logoBase64;

  bool _hasLogo() => _logoBytes != null || _existingLogoBase64() != null;

  Uint8List _logoToDisplay() {
    if (_logoBytes != null) return _logoBytes!;
    return base64Decode(_existingLogoBase64()!);
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;
    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _logoBytes = bytes;
      _logoFileName = result.files.single.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final app = context.read<AppProvider>();
      final now = DateTime.now().toIso8601String();
      if (_logoBytes != null && _logoFileName != null) {
        final base64 = base64Encode(_logoBytes!);
        final s = CenterReportSettings(
          centerId: app.currentCenter?.id ?? '',
          logoBase64: base64,
          logoFileName: _logoFileName,
          arabicHeaderText: _arabicHeaderCtrl.text,
          englishHeaderText: _englishHeaderCtrl.text,
          defaultReportTitle: _reportTitleCtrl.text,
          defaultTechnicalSupervisorName: _supervisorNameCtrl.text,
          footerNotes: _footerNotesCtrl.text,
          reportsToFund: _reportsToFund,
          fundName: _fundNameCtrl.text,
          showFundCardNumber: _showFundCardNumber,
          showReferralDate: _showReferralDate,
          showReferralSource: _showReferralSource,
          updatedAt: now,
        );
        await app.saveCenterReportSettings(s);
      } else {
        final base = app.centerReportSettings ??
            CenterReportSettings.defaults(app.currentCenter?.id ?? '');
        final s = base.copyWith(
          arabicHeaderText: _arabicHeaderCtrl.text,
          englishHeaderText: _englishHeaderCtrl.text,
          defaultReportTitle: _reportTitleCtrl.text,
          defaultTechnicalSupervisorName: _supervisorNameCtrl.text,
          footerNotes: _footerNotesCtrl.text,
          reportsToFund: _reportsToFund,
          fundName: _fundNameCtrl.text,
          showFundCardNumber: _showFundCardNumber,
          showReferralDate: _showReferralDate,
          showReferralSource: _showReferralSource,
          updatedAt: now,
        );
        await app.saveCenterReportSettings(s);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات التقارير')),
      body: _loaded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('الشعار',
                              style: SanadText.subtitle(context)),
                          const SizedBox(height: 12),
                          Center(
                            child: _hasLogo()
                                ? Image.memory(_logoToDisplay(), height: 100)
                                : const Text('لا يوجد شعار'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.image),
                                label: const Text('اختيار شعار'),
                              ),
                              const SizedBox(width: 8),
                              if (_hasLogo())
                                TextButton.icon(
                                  onPressed: () async {
                                    await context
                                        .read<AppProvider>()
                                        .clearCenterReportLogo();
                                    if (!mounted) return;
                                    setState(() {
                                      _logoBytes = null;
                                      _logoFileName = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('إزالة'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('النصوص',
                              style: SanadText.subtitle(context)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _arabicHeaderCtrl,
                            decoration: const InputDecoration(
                                labelText: 'نص الترويسة (عربي)'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _englishHeaderCtrl,
                            decoration: const InputDecoration(
                                labelText: 'نص الترويسة (إنجليزي)'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reportTitleCtrl,
                            decoration: const InputDecoration(
                                labelText: 'عنوان التقرير الافتراضي'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _supervisorNameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'المشرف الفني الافتراضي'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _footerNotesCtrl,
                            decoration: const InputDecoration(
                                labelText: 'ملاحظات التذييل'),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('خيارات التقرير',
                              style: SanadText.subtitle(context)),
                          SwitchListTile(
                            title: const Text('توجيه التقارير للجهة الممولة'),
                            value: _reportsToFund,
                            onChanged: (v) =>
                                setState(() => _reportsToFund = v),
                          ),
                          if (_reportsToFund) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _fundNameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'اسم الجهة الممولة'),
                            ),
                            const Divider(),
                            CheckboxListTile(
                              title: const Text('إظهار رقم بطاقة الحالة'),
                              value: _showFundCardNumber,
                              onChanged: (v) => setState(
                                  () => _showFundCardNumber = v ?? false),
                            ),
                            CheckboxListTile(
                              title: const Text('إظهار تاريخ الإحالة'),
                              value: _showReferralDate,
                              onChanged: (v) => setState(
                                  () => _showReferralDate = v ?? false),
                            ),
                            CheckboxListTile(
                              title: const Text('إظهار جهة الإحالة'),
                              value: _showReferralSource,
                              onChanged: (v) => setState(
                                  () => _showReferralSource = v ?? false),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label:
                            Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
