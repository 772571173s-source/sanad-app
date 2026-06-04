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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
              onPressed: () => _showForm(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('إضافة موظف'))),
      const SizedBox(height: 12),
      if (app.staff.isEmpty)
        const EmptyState(
            icon: Icons.badge_outlined,
            title: 'لا توجد حسابات موظفين',
            message: 'أنشئ مدير مركز أو موظفين حسب صلاحيتك الحالية.')
      else
        ResponsiveGrid(
          children: app.staff.map((account) {
            return AppCard(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(account.name),
                subtitle: Text('${account.email}\n${account.role.label}'),
                trailing: Chip(label: Text(account.isActive ? 'نشط' : 'متوقف')),
              ),
            );
          }).toList(),
        ),
    ]);
  }

  Future<void> _showForm(BuildContext context) async {
    final app = context.read<AppProvider>();
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    UserRole role = app.isOwner ? UserRole.centerManager : UserRole.specialist;
    final centers = _uniqueCenters(app.centers);
    String? selectedCenterId =
        app.currentCenter?.id ?? (centers.isEmpty ? null : centers.first.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حساب'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(320, 560).toDouble(),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 10),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'البريد')),
                const SizedBox(height: 10),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'كلمة مرور مؤقتة')),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: (app.isOwner
                          ? [UserRole.centerManager]
                          : [
                              UserRole.specialist,
                              UserRole.dataEntry,
                              UserRole.programEntry
                            ])
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(item.label)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? role),
                ),
                if (app.isOwner) ...[
                  const SizedBox(height: 10),
                  if (centers.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text(
                          'لا توجد مراكز متاحة. أضف مركزًا أولًا من شاشة إدارة المراكز.'),
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
                                  overflow: TextOverflow.ellipsis)))
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
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => runWithFeedback(context, () async {
                final centerId =
                    app.isOwner ? selectedCenterId : app.activeCenterId;
                if (name.text.trim().isEmpty ||
                    email.text.trim().isEmpty ||
                    password.text.length < 8 ||
                    centerId == null ||
                    centerId.isEmpty) {
                  throw StateError(
                      'أكمل بيانات الحساب واختر المركز، وكلمة المرور 8 أحرف على الأقل.');
                }
                await app.saveStaffUser(AppUser(
                    id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                    centerId: centerId,
                    email: email.text.trim(),
                    passwordHash: AuthService.hashPassword(password.text),
                    name: name.text.trim(),
                    role: role,
                    forcePasswordChange: true));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  List<SanadCenter> _uniqueCenters(List<SanadCenter> centers) {
    final byId = <String, SanadCenter>{};
    for (final center in centers) {
      byId.putIfAbsent(center.id, () => center);
    }
    return byId.values.toList();
  }
}
