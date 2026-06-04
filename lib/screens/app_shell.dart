import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'centers_screen.dart';
import 'dashboard_screen.dart';
import 'data_entry_screen.dart';
import 'exercises_parent_screen.dart';
import 'owner_support_screen.dart';
import 'programs_screen.dart';
import 'rewards_screen.dart';
import 'sessions_screen.dart';
import 'settings_hub_screen.dart';
import 'staff_screen.dart';
import 'student_profile_screen.dart';
import 'students_screen.dart';
import 'tools_screen.dart';

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
    if (index >= items.length) {
      index = 0;
    }
    final selected = app.user?.forcePasswordChange == true
        ? const _NavItem(
            'تغيير كلمة المرور', Icons.lock_reset, SettingsHubScreen())
        : items[index];

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
                  SizedBox(
                    width: 270,
                    child: _Sidebar(
                      items: items,
                      index: index,
                      onChanged: (value) => setState(() => index = value),
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            }
            return Scaffold(
              appBar: AppBar(title: Text(selected.title)),
              drawer: Drawer(
                child: _Sidebar(
                  items: items,
                  index: index,
                  onChanged: (value) => setState(() => index = value),
                ),
              ),
              body: content,
            );
          },
        ),
      ),
    );
  }

  List<_NavItem> _items(AppProvider app) {
    if (app.isOwner) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('المراكز', Icons.business_outlined, CentersScreen()),
        _NavItem('المدراء', Icons.manage_accounts_outlined, StaffScreen()),
        _NavItem('المساعدة', Icons.support_agent, OwnerSupportScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    if (app.isCenterManager) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('الموظفون', Icons.manage_accounts_outlined, StaffScreen()),
        _NavItem('الأدوات', Icons.construction_outlined, ToolsScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    if (app.isSpecialist) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
            'البرامج العلاجية', Icons.extension_outlined, ProgramsScreen()),
        _NavItem(
            'ملف الطالب', Icons.folder_shared_outlined, StudentProfileScreen()),
        _NavItem('الجلسات', Icons.timer_outlined, SessionsScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    if (app.isDataEntry) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('الإدخال', Icons.person_add_alt, DataEntryScreen()),
        _NavItem('الطلاب', Icons.groups_2_outlined, StudentsScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    if (app.isProgramEntry) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('البرامج', Icons.extension_outlined, ProgramsScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    if (app.isParent) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
            'ملف الطالب', Icons.folder_shared_outlined, StudentProfileScreen()),
        _NavItem('واجهة الأهل', Icons.family_restroom_outlined,
            ExercisesParentScreen()),
        _NavItem('المكافآت', Icons.emoji_events_outlined, RewardsScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    return const [
      _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
    ];
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
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(app.user?.name ?? ''),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'الوضع الليلي',
          onPressed: app.toggleTheme,
          icon: Icon(app.darkMode ? Icons.light_mode : Icons.dark_mode),
        ),
        IconButton(
          tooltip: 'خروج',
          onPressed: app.logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: .55),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Text('س'),
                ),
                title: const Text('Sanad',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  context.watch<AppProvider>().currentCenter?.name ??
                      'إدارة التخاطب والتأهيل',
                ),
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
                        selectedTileColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(item.icon),
                        title: Text(item.title),
                        onTap: () {
                          onChanged(itemIndex);
                          if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                            Navigator.pop(context);
                          }
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
