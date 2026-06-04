import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/feedback.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(app.user?.forcePasswordChange == true ? 'يجب تغيير كلمة المرور التجريبية قبل المتابعة.' : 'تغيير كلمة المرور', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
            const SizedBox(height: 12),
            TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => runWithFeedback(context, () async {
                if (password.text != confirm.text) throw StateError('كلمتا المرور غير متطابقتين.');
                await context.read<AppProvider>().changePassword(password.text);
                password.clear();
                confirm.clear();
              }, success: 'تم تغيير كلمة المرور.'),
              icon: const Icon(Icons.lock_reset),
              label: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );
  }
}
