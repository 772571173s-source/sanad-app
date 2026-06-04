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
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _showForm(context), icon: const Icon(Icons.person_add_alt), label: const Text('إضافة موظف'))),
      const SizedBox(height: 12),
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
    final password = TextEditingController(text: '123456');
    UserRole role = app.isOwner ? UserRole.admin : UserRole.specialist;
    SanadCenter? center = app.currentCenter;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حساب'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 10),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد')),
              const SizedBox(height: 10),
              TextField(controller: password, decoration: const InputDecoration(labelText: 'كلمة مرور مؤقتة')),
              const SizedBox(height: 10),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'الدور'),
                items: [if (app.isOwner) UserRole.admin, UserRole.specialist].map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
                onChanged: (value) => setDialogState(() => role = value ?? role),
              ),
              if (app.isOwner) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<SanadCenter>(
                  initialValue: center,
                  decoration: const InputDecoration(labelText: 'المركز'),
                  items: app.centers.map((item) => DropdownMenuItem(value: item, child: Text(item.name))).toList(),
                  onChanged: (value) => setDialogState(() => center = value),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => runWithFeedback(context, () async {
                final selectedCenter = center;
                if (name.text.trim().isEmpty || email.text.trim().isEmpty || selectedCenter == null) throw StateError('أكمل بيانات الحساب.');
                await app.saveStaffUser(AppUser(id: 'user_${DateTime.now().millisecondsSinceEpoch}', centerId: selectedCenter.id, email: email.text.trim(), passwordHash: AuthService.hashPassword(password.text), name: name.text.trim(), role: role, forcePasswordChange: true));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
