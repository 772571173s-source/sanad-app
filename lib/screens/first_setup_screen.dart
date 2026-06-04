import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/feedback.dart';

class FirstSetupScreen extends StatefulWidget {
  const FirstSetupScreen({super.key});

  @override
  State<FirstSetupScreen> createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('إعداد سند لأول مرة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('أنشئ حساب مالك النظام. لن يتم إنشاء أي حساب أو مركز تلقائيًا.'),
                      const SizedBox(height: 18),
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم مالك النظام')),
                      const SizedBox(height: 12),
                      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد')),
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                      const SizedBox(height: 12),
                      TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => runWithFeedback(
                          context,
                          () => context.read<AppProvider>().createSystemOwner(
                                name: name.text,
                                email: email.text,
                                password: password.text,
                                confirmPassword: confirm.text,
                              ),
                          success: 'تم إنشاء مالك النظام. سجل الدخول الآن.',
                        ),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('إنشاء مالك النظام'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
