import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final accounts = app.isOwner
        ? app.staff
            .where((account) => account.role == UserRole.centerManager)
            .toList()
        : app.staff
            .where((account) =>
                account.role == UserRole.clinicalSupervisor ||
                account.role == UserRole.specialist ||
                account.role == UserRole.dataEntry ||
                account.role == UserRole.therapyProgramEntry ||
                account.role == UserRole.coordinator)
            .toList();
    final title = app.isOwner ? 'مدراء المراكز' : 'الموظفون';
    final addLabel = app.isOwner ? 'إنشاء مدير' : 'إضافة موظف';
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TherapyCard(
        title: title,
        icon: Icons.manage_accounts_outlined,
        trailing: FilledButton.icon(
          onPressed: () => _showForm(context),
          icon: const Icon(Icons.person_add_alt),
          label: Text(addLabel),
        ),
        child: Text(app.isOwner
            ? 'إدارة حسابات مدراء المراكز وربط كل مدير بمركزه.'
            : 'إدارة حسابات فريق المركز وصلاحياتهم التشغيلية.'),
      ),
      const SizedBox(height: AppSpacing.md),
      if (accounts.isEmpty)
        EmptyState(
          icon: Icons.badge_outlined,
          title: app.isOwner ? 'لا يوجد مدراء مراكز' : 'لا توجد حسابات موظفين',
          message: app.isOwner
              ? 'أنشئ مديرًا واربطه بمركز حتى يبدأ المركز بالعمل.'
              : 'أضف أخصائيًا أو مدخل بيانات أو مدخل برامج حسب حاجة المركز.',
          action: FilledButton.icon(
            onPressed: () => _showForm(context),
            icon: const Icon(Icons.person_add_alt),
            label: Text(addLabel),
          ),
        )
      else
        ResponsiveGrid(
          children: accounts
              .map((account) => _ManagerProfileCard(
                    account: account,
                    centerName: _centerName(app.centers, account.centerId),
                    capabilityProgramIds:
                        app.specialistCapabilityProgramsByUser[account.id] ?? [],
                    therapyProgramNames: app.therapyPrograms
                        .where((p) => (app.specialistCapabilityProgramsByUser[
                                    account.id]
                                ?.contains(p.id) ??
                            false))
                        .map((p) => p.name)
                        .toList(),
                    onEdit: () => _showForm(context, account: account),
                    onPassword: () => _changePassword(context, account),
                    onToggle: () => _toggleAccount(context, account),
                    onDelete: () => _deleteManager(context, account),
                    onManagePrograms: account.role == UserRole.specialist
                        ? () => _manageCapabilities(context, account)
                        : null,
                  ))
              .toList(),
        ),
      ],
      ),
    );
  }

  Future<void> _showForm(BuildContext context, {AppUser? account}) async {
    final app = context.read<AppProvider>();
    final name = TextEditingController(text: account?.name ?? '');
    final email = TextEditingController(text: account?.email ?? '');
    final password = TextEditingController();
    UserRole role = account?.role ??
        (app.isOwner ? UserRole.centerManager : UserRole.specialist);
    final centers = _uniqueCenters(app.centers);
    String? selectedCenterId = account?.centerId ??
        app.currentCenter?.id ??
        (centers.isEmpty ? null : centers.first.id);
    final selectedPrograms = <String>{};
    if (account != null && account.role == UserRole.specialist) {
      final existing =
          app.specialistCapabilityProgramsByUser[account.id] ?? [];
      selectedPrograms.addAll(existing);
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(account == null ? 'إضافة حساب' : 'تعديل حساب'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(320, 560).toDouble(),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'اسم المستخدم أو البريد'),
                ),
                if (account == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: password,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration:
                        const InputDecoration(labelText: 'كلمة مرور مؤقتة'),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'نوع الحساب'),
                  items: (app.isOwner
                          ? [UserRole.centerManager]
                          : [
                              UserRole.specialist,
                              UserRole.dataEntry,
                              UserRole.therapyProgramEntry,
                              UserRole.clinicalSupervisor,
                              UserRole.coordinator,
                            ])
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(item.label)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      role = value ?? role;
                      if (role != UserRole.specialist) {
                        selectedPrograms.clear();
                      }
                    });
                  },
                ),
                if (role == UserRole.specialist && !app.isOwner) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Text('البرامج العلاجية',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  if (app.therapyPrograms.isEmpty)
                    const Text('لا توجد برامج علاجية في المركز.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ...app.therapyPrograms.map((program) {
                      return CheckboxListTile(
                        dense: true,
                        title: Text(program.name, style: const TextStyle(fontSize: 14)),
                        value: selectedPrograms.contains(program.id),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedPrograms.add(program.id);
                            } else {
                              selectedPrograms.remove(program.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                ],
                if (app.isOwner) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (centers.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text(
                          'لا توجد مراكز متاحة. أضف مركزًا أولًا من شاشة المراكز.'),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue:
                          centers.any((center) => center.id == selectedCenterId)
                              ? selectedCenterId
                              : centers.first.id,
                      decoration: const InputDecoration(labelText: 'المركز'),
                      items: centers
                          .map((center) => DropdownMenuItem<String>(
                                value: center.id,
                                child: Text(center.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedCenterId = value),
                    ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => runWithFeedback(context, () async {
                final centerId =
                    app.isOwner ? selectedCenterId : app.activeCenterId;
                if (name.text.trim().isEmpty ||
                    email.text.trim().isEmpty ||
                    centerId == null ||
                    centerId.isEmpty ||
                    (account == null && password.text.length < 8)) {
                  throw StateError(
                      'أكمل بيانات الحساب واختر المركز، وكلمة المرور لا تقل عن 8 أحرف.');
                }
                if (role == UserRole.specialist && selectedPrograms.isEmpty) {
                  throw StateError(
                      'يجب اختيار برنامج علاجي واحد على الأقل للأخصائي.');
                }
                final userId = account?.id ??
                    'user_${DateTime.now().millisecondsSinceEpoch}';
                await app.saveStaffUser(AppUser(
                  id: userId,
                  centerId: centerId,
                  email: email.text.trim(),
                  passwordHash: account?.passwordHash ??
                      AuthService.hashPassword(password.text),
                  name: name.text.trim(),
                  role: role,
                  studentId: account?.studentId,
                  forcePasswordChange: account?.forcePasswordChange ?? true,
                  isDemo: account?.isDemo ?? false,
                  isActive: account?.isActive ?? true,
                  createdAt: account?.createdAt ?? '',
                  updatedAt: DateTime.now().toIso8601String(),
                ));
                if (role == UserRole.specialist && selectedPrograms.isNotEmpty) {
                  await app.setSpecialistCapabilities(
                      userId, selectedPrograms.toList());
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, AppUser account) async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(300, 420).toDouble(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'كلمة المرور الجديدة'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: confirm,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'تأكيد كلمة المرور'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => runWithFeedback(context, () async {
              if (password.text != confirm.text) {
                throw StateError('كلمتا المرور غير متطابقتين.');
              }
              await context
                  .read<AppProvider>()
                  .changeStaffPassword(account, password.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, success: 'تم تغيير كلمة المرور.'),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAccount(BuildContext context, AppUser account) {
    return runWithFeedback(
      context,
      () => context
          .read<AppProvider>()
          .setStaffUserActive(account, !account.isActive),
      success: 'تم تحديث حالة الحساب.',
    );
  }

  Future<void> _deleteManager(BuildContext context, AppUser account) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('حذف المدير'),
            content: const Text(
                'هل أنت متأكد من حذف هذا المدير؟\nسيتم حذف حساب الدخول الخاص به'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
      context,
      () => context.read<AppProvider>().deleteStaffUser(account),
      success: 'تم حذف المدير.',
    );
  }

  String _centerName(List<SanadCenter> centers, String id) {
    for (final center in centers) {
      if (center.id == id) return center.name;
    }
    return 'غير مرتبط';
  }

  List<SanadCenter> _uniqueCenters(List<SanadCenter> centers) {
    final byId = <String, SanadCenter>{};
    for (final center in centers) {
      byId.putIfAbsent(center.id, () => center);
    }
    return byId.values.toList();
  }

  Future<void> _manageCapabilities(BuildContext context, AppUser account) async {
    final app = context.read<AppProvider>();
    final existing = app.specialistCapabilityProgramsByUser[account.id] ?? [];
    final programs = app.therapyPrograms;

    final selected = Set<String>.from(existing);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('البرامج المتاحة - ${account.name}'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(320, 480).toDouble(),
            child: programs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('لا توجد برامج علاجية متاحة. أضف برامج أولاً.'),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: programs.map((program) {
                        return CheckboxListTile(
                          title: Text(program.name),
                          subtitle: program.description.isNotEmpty
                              ? Text(program.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                          value: selected.contains(program.id),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(program.id);
                              } else {
                                selected.remove(program.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => runWithFeedback(context, () async {
                await app.setSpecialistCapabilities(
                    account.id, selected.toList());
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }, success: 'تم حفظ البرامج.'),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerProfileCard extends StatefulWidget {
  const _ManagerProfileCard({
    required this.account,
    required this.centerName,
    required this.capabilityProgramIds,
    required this.therapyProgramNames,
    required this.onEdit,
    required this.onPassword,
    required this.onToggle,
    required this.onDelete,
    this.onManagePrograms,
  });

  final AppUser account;
  final String centerName;
  final List<String> capabilityProgramIds;
  final List<String> therapyProgramNames;
  final VoidCallback onEdit;
  final VoidCallback onPassword;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onManagePrograms;

  @override
  State<_ManagerProfileCard> createState() => _ManagerProfileCardState();
}

class _ManagerProfileCardState extends State<_ManagerProfileCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedScale(
        scale: hovering ? 1.01 : 1,
        duration: const Duration(milliseconds: 160),
        child: TherapyCard(
          title: account.name,
          icon: Icons.admin_panel_settings_outlined,
          trailing: AppPill(
            label: account.isActive ? 'نشط' : 'موقوف',
            icon: account.isActive ? Icons.check_circle_outline : Icons.block,
            selected: account.isActive,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      account.name.isEmpty ? 'م' : account.name.substring(0, 1),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            account.email,
                            maxLines: 1,
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(widget.centerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppPill(label: account.role.label, icon: Icons.verified_user),
                  AppPill(
                    label: account.email.isNotEmpty
                        ? account.email
                        : account.role.label,
                    icon: Icons.badge_outlined,
                  ),
                  AppPill(
                    label: widget.centerName,
                    icon: Icons.business_outlined,
                  ),
                ],
              ),
              if (account.role == UserRole.specialist && widget.therapyProgramNames.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: widget.therapyProgramNames.map((name) {
                    return AppPill(
                      label: name,
                      icon: Icons.folder_outlined,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل الحساب'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onPassword,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('تغيير كلمة المرور'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onToggle,
                    icon: Icon(account.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline),
                    label: Text(account.isActive ? 'إيقاف' : 'تفعيل'),
                  ),
                  if (widget.onManagePrograms != null)
                    FilledButton.tonalIcon(
                      onPressed: widget.onManagePrograms,
                      icon: const Icon(Icons.folder_outlined),
                      label: const Text('البرامج'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red),
                    label: const Text('حذف المدير'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
