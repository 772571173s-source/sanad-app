import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'backup_screen.dart';
import 'center_settings_screen.dart';
import 'centers_screen.dart';
import 'dashboard_screen.dart';
import 'evaluations_screen.dart';
import 'exercises_parent_screen.dart';
import 'password_screen.dart';
import 'plans_screen.dart';
import 'reports_screen.dart';
import 'rewards_screen.dart';
import 'sessions_screen.dart';
import 'sign_library_screen.dart';
import 'staff_screen.dart';
import 'student_profile_screen.dart';
import 'students_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final items = _items(app);
    if (index >= items.length) index = 0;
    final selected = app.user?.forcePasswordChange == true ? const _NavItem('تغيير كلمة المرور', Icons.lock_reset, PasswordScreen()) : items[index];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            final content = AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SingleChildScrollView(
                key: ValueKey(selected.title),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(title: selected.title),
                    const SizedBox(height: 16),
                    selected.screen,
                  ],
                ),
              ),
            );
            if (wide) {
              return Row(
                children: [
                  SizedBox(width: 270, child: _Sidebar(items: items, index: index, onChanged: (value) => setState(() => index = value))),
                  Expanded(child: content),
                ],
              );
            }
            return Scaffold(
              appBar: AppBar(title: Text(selected.title)),
              drawer: Drawer(child: _Sidebar(items: items, index: index, onChanged: (value) => setState(() => index = value))),
              body: content,
            );
          },
        ),
      ),
    );
  }

  List<_NavItem> _items(AppProvider app) {
    final base = <_NavItem>[
      const _NavItem('لوحة التحكم', Icons.dashboard_outlined, DashboardScreen()),
      if (!app.isParent) const _NavItem('الطلاب', Icons.groups_2_outlined, StudentsScreen()),
      if (!app.isParent) const _NavItem('ملف الطالب', Icons.folder_shared_outlined, StudentProfileScreen()),
      if (!app.isParent) const _NavItem('الجلسات', Icons.timer_outlined, SessionsScreen()),
      if (!app.isParent) const _NavItem('تقييم الحروف', Icons.record_voice_over_outlined, EvaluationsScreen()),
      if (!app.isParent) const _NavItem('الخطط الدراسية', Icons.route_outlined, PlansScreen()),
      if (!app.isParent) const _NavItem('لغة الإشارة', Icons.sign_language_outlined, SignLibraryScreen()),
      const _NavItem('واجهة الأهل', Icons.family_restroom_outlined, ExercisesParentScreen()),
      const _NavItem('المكافآت', Icons.emoji_events_outlined, RewardsScreen()),
      if (!app.isParent) const _NavItem('التقارير PDF', Icons.picture_as_pdf_outlined, ReportsScreen()),
      if (app.canManageCenters) const _NavItem('إدارة المراكز', Icons.business_outlined, CentersScreen()),
      if (app.canManageStaff) const _NavItem('الموظفون والمدراء', Icons.manage_accounts_outlined, StaffScreen()),
      if (!app.isParent) const _NavItem('إعدادات المركز', Icons.settings_outlined, CenterSettingsScreen()),
      if (app.isOwner || app.isAdmin) const _NavItem('Backup', Icons.backup_outlined, BackupScreen()),
      const _NavItem('تغيير كلمة المرور', Icons.lock_reset, PasswordScreen()),
    ];
    return base;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
        Text(app.user?.name ?? ''),
        const SizedBox(width: 8),
        IconButton(tooltip: 'الوضع الليلي', onPressed: app.toggleTheme, icon: Icon(app.darkMode ? Icons.light_mode : Icons.dark_mode)),
        IconButton(tooltip: 'خروج', onPressed: app.logout, icon: const Icon(Icons.logout)),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.items, required this.index, required this.onChanged});

  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary, child: const Text('س')),
                title: const Text('Sanad MVP', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(context.watch<AppProvider>().currentCenter?.name ?? 'إدارة التخاطب والتأهيل'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        selected: itemIndex == index,
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: Icon(item.icon),
                        title: Text(item.title),
                        onTap: () {
                          onChanged(itemIndex);
                          if (Scaffold.maybeOf(context)?.hasDrawer ?? false) Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.title, this.icon, this.screen);

  final String title;
  final IconData icon;
  final Widget screen;
}
