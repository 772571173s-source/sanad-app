import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 720;
                    final pad = narrow ? 16.0 : 28.0;
                    final banner = Container(
                      constraints: BoxConstraints(minHeight: narrow ? 200 : 420),
                      color: const Color(0xFF123E3A),
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('سند',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: narrow ? 34 : 42,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          const Text(
                              'نظام إدارة التخاطب والتأهيل للمراكز: مراكز، موظفون، طلاب، جلسات، واجبات، وتقارير.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Color(0xFFD8ECE8), height: 1.7)),
                        ],
                      ),
                    );
                    final form = Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('تسجيل الدخول',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 18),
                          TextField(
                              controller: email,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                  labelText: 'اسم المستخدم أو رقم الجوال')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'كلمة المرور')),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Text(error!,
                                style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: app.loading ? null : _login,
                            icon: const Icon(Icons.login),
                            label:
                                Text(app.loading ? 'جاري الدخول...' : 'دخول'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'استخدم الحساب الذي أنشأته في أول تشغيل أو الحساب الذي أنشأه مدير المركز.'),
                        ],
                      ),
                    );
                    if (narrow) {
                      return Column(children: [banner, form]);
                    }
                    return Row(
                      children: [
                        Expanded(child: banner),
                        Expanded(child: form),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    try {
      final ok =
          await context.read<AppProvider>().login(email.text, password.text);
      if (!ok && mounted) setState(() => error = 'بيانات الدخول غير صحيحة.');
    } catch (exception) {
      if (!mounted) return;
      setState(
          () => error = exception.toString().replaceFirst('Bad state: ', ''));
    }
  }
}
