import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'centers_screen.dart';
import 'dashboard_screen.dart';
import 'data_entry_screen.dart';
import 'evaluations_screen.dart';
import 'owner_support_screen.dart';
import 'parent_dashboard_screen.dart';
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
  bool lastSupportMode = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (lastSupportMode != app.isSupportMode) {
      index = 0;
      lastSupportMode = app.isSupportMode;
    }
    final items = _items(app);
    if (index >= items.length) {
      index = 0;
    }
    final selected = app.user?.forcePasswordChange == true
        ? const _NavItem(
            'ط·آ·ط¹آ¾ط·آ·ط·â€؛ط·آ¸ط¸آ¹ط·آ¸ط¸آ¹ط·آ·ط¢آ± ط·آ¸ط¦â€™ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ© ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط«â€ ط·آ·ط¢آ±',
            Icons.lock_reset,
            SettingsHubScreen(),
          )
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
                    if (app.isSupportMode) ...[
                      const SizedBox(height: 12),
                      _SupportModeBanner(
                        centerName: app.currentCenter?.name ?? '',
                        onExit: () async {
                          await app.exitSupportMode();
                          setState(() => index = 0);
                        },
                      ),
                    ],
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
    if (app.isSupportMode) {
      return [
        const _NavItem(
            'Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ¨',
          Icons.groups_2_outlined,
          StudentsScreen(onOpenProfile: () => setState(() => index = 2)),
        ),
        const _NavItem(
          'ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬â€چط·آ¸ط¸آ¾ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¨',
          Icons.folder_shared_outlined,
          StudentProfileScreen(),
        ),
        const _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ¸ط«â€ ط·آ·ط¢آ¸ط·آ¸ط¸آ¾ط·آ¸ط«â€ ط·آ¸أ¢â‚¬آ ',
          Icons.manage_accounts_outlined,
          StaffScreen(),
        ),
        const _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ£ط·آ·ط¢آ¯ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ·ط¹آ¾',
            Icons.construction_outlined,
            ToolsScreen()),
        const _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¹آ¾',
          Icons.settings_outlined,
          SettingsHubScreen(),
        ),
      ];
    }
    if (app.isOwner) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ·ط¢آ§ط·آ¸ط¦â€™ط·آ·ط¢آ²',
            Icons.business_outlined,
            CentersScreen()),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ·ط¢آ±ط·آ·ط¢آ§ط·آ·ط·إ’',
            Icons.manage_accounts_outlined,
            StaffScreen()),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ©',
            Icons.support_agent,
            OwnerSupportScreen()),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¹آ¾',
            Icons.settings_outlined,
            SettingsHubScreen()),
      ];
    }
    if (app.isCenterManager) {
      return [
        const _NavItem(
            'Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ¨',
          Icons.groups_2_outlined,
          StudentsScreen(onOpenProfile: () => setState(() => index = 2)),
        ),
        const _NavItem(
          'ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬â€چط·آ¸ط¸آ¾ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¨',
          Icons.folder_shared_outlined,
          StudentProfileScreen(),
        ),
        const _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ¸ط«â€ ط·آ·ط¢آ¸ط·آ¸ط¸آ¾ط·آ¸ط«â€ ط·آ¸أ¢â‚¬آ ',
          Icons.manage_accounts_outlined,
          StaffScreen(),
        ),
        const _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ£ط·آ·ط¢آ¯ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ·ط¹آ¾',
            Icons.construction_outlined,
            ToolsScreen()),
        const _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¹آ¾',
          Icons.settings_outlined,
          SettingsHubScreen(),
        ),
      ];
    }
    if (app.isSpecialist) {
      return [
        const _NavItem(
            'Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ¨',
          Icons.groups_2_outlined,
          StudentsScreen(
            onOpenProfile: () => setState(() => index = 2),
            onStartSession: () => setState(() => index = 4),
          ),
        ),
        const _NavItem(
          'ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬â€چط·آ¸ط¸آ¾ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¨',
          Icons.folder_shared_outlined,
          StudentProfileScreen(),
        ),
        const _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¹آ¾ط·آ¸أ¢â‚¬ع‘ط·آ¸ط¸آ¹ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬آ¦ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¹ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ¬ط·آ¸ط¸آ¹',
          Icons.fact_check_outlined,
          EvaluationsScreen(),
        ),
        const _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¬ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¹آ¾',
            Icons.timer_outlined,
            SessionsScreen()),
        const _NavItem(
          'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¹آ¾',
          Icons.settings_outlined,
          SettingsHubScreen(),
        ),
      ];
    }
    if (app.isDataEntry) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¯ط·آ·ط¢آ®ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چ',
            Icons.person_add_alt,
            DataEntryScreen()),
        _NavItem('ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ·ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ¨',
            Icons.groups_2_outlined, StudentsScreen()),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¹آ¾',
            Icons.settings_outlined,
            SettingsHubScreen()),
      ];
    }
    if (app.isProgramEntry) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
          'ط·آ§ط¸â€‍ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ ط·آ§ط¸â€‍ط·آ¹ط¸â€‍ط·آ§ط·آ¬ط¸ظ¹',
          Icons.fact_check_outlined,
          EvaluationsScreen(),
        ),
        _NavItem('ط·آ§ط¸â€‍ط·آ¥ط·آ¹ط·آ¯ط·آ§ط·آ¯ط·آ§ط·ع¾',
            Icons.settings_outlined, SettingsHubScreen()),
      ];
    }
    if (app.isParent) {
      return const [
        _NavItem(
          'ط·آ¸أ¢â‚¬â€چط·آ¸ط«â€ ط·آ·ط¢آ­ط·آ·ط¢آ© ط·آ¸ط«â€ ط·آ¸أ¢â‚¬â€چط·آ¸ط¸آ¹ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ£ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±',
          Icons.family_restroom_outlined,
          ParentDashboardScreen(),
        ),
        _NavItem(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¥ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¹آ¾',
            Icons.settings_outlined,
            SettingsHubScreen()),
      ];
    }
    return const [
      _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
    ];
  }
}

class _SupportModeBanner extends StatelessWidget {
  const _SupportModeBanner({required this.centerName, required this.onExit});

  final String centerName;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return TherapyCard(
      icon: Icons.support_agent,
      title:
          'ط·آ·ط¢آ£ط·آ¸أ¢â‚¬آ ط·آ·ط¹آ¾ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¢ط·آ¸أ¢â‚¬آ  ط·آ·ط¹آ¾ط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¢آ¹ط·آ·ط¢آ¯ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²: ${centerName.isEmpty ? '-' : centerName}',
      trailing: FilledButton.tonalIcon(
        onPressed: onExit,
        icon: const Icon(Icons.keyboard_return),
        label: const Text(
            'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¹ط·آ¸ط«â€ ط·آ·ط¢آ¯ط·آ·ط¢آ© ط·آ·ط¢آ¥ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ° ط·آ·ط¢آ¥ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ±ط·آ·ط¢آ© ط·آ·ط¢آ³ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ¯'),
      ),
      child: const Text(
        'ط·آ·ط¹آ¾ط·آ·ط¢آ¹ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬â€چ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¢ط·آ¸أ¢â‚¬آ  ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ®ط·آ¸أ¢â‚¬â€چ ط·آ·ط¢آ¨ط·آ¸ط¸آ¹ط·آ·ط¢آ¦ط·آ·ط¢آ© ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ² ط·آ·ط¢آ¨ط·آ·ط¢آµط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ­ط·آ¸ط¸آ¹ط·آ·ط¢آ§ط·آ·ط¹آ¾ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ·ط¢آ± ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²ط·آ·ط¥â€™ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¹ ط·آ·ط¢آ¨ط·آ¸أ¢â‚¬ع‘ط·آ·ط¢آ§ط·آ·ط·إ’ ط·آ·ط¢آ­ط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¢آ¨ط·آ¸ط¦â€™ ط·آ¸ط¦â€™ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸ط¦â€™ ط·آ·ط¢آ³ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ¯.',
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ³ط·آ·ط¹آ¾ط·آ·ط¢آ®ط·آ·ط¢آ¯ط·آ¸أ¢â‚¬آ¦ ط·آ·ط¢آ³ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ¯';
    final roleLabel = _roleLabel(user?.role);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(name),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(app, title),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ­ط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¢آ¨',
          offset: const Offset(0, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              app.logout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: _AccountMenuHeader(
                name: name,
                roleLabel: roleLabel,
                role: user?.role,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: _ProfileMenuItem(
                icon: Icons.logout,
                label:
                    'ط·آ·ط¹آ¾ط·آ·ط¢آ³ط·آ·ط¢آ¬ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬â€چ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ®ط·آ·ط¢آ±ط·آ¸ط«â€ ط·آ·ط¢آ¬',
                danger: true,
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoleAvatar(role: user?.role, name: name, radius: 21),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                    ),
                    Text(
                      roleLabel,
                      style: SanadText.muted(context),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير، $name';
    }
    if (hour < 17) {
      return 'أهلًا، $name';
    }
    return 'مساء الخير، $name';
  }

  String _subtitle(AppProvider app, String title) {
    if (app.isOwner) return 'ط¥ط¯ط§ط±ط© ط³ظ†ط¯ ظˆط§ظ„طھط£ظ‡ظٹظ„';
    if (app.isCenterManager) {
      final center = app.currentCenter?.name;
      return center == null || center.isEmpty
          ? 'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ط±ظƒط²'
          : 'ط¥ط¯ط§ط±ط© ظ…ط±ظƒط² $center';
    }
    if (app.isSpecialist) {
      return 'ظ…طھط§ط¨ط¹ط© ط§ظ„طھظ‚ظٹظٹظ…ط§طھ ظˆط§ظ„ط£ظ‡ط¯ط§ظپ ظˆط§ظ„ط¬ظ„ط³ط§طھ ط§ظ„ط¹ظ„ط§ط¬ظٹط©';
    }
    if (app.isParent) {
      return 'ظ…طھط§ط¨ط¹ط© ط§ظ„ظˆط§ط¬ط¨ط§طھ ظˆط§ظ„طھظ‚ط¯ظ… ط§ظ„ظ…ظ†ط²ظ„ظٹ';
    }
    if (app.isDataEntry) {
      return 'طھظ†ط¸ظٹظ… ط¥ط¯ط®ط§ظ„ ط§ظ„ط·ظ„ط§ط¨ ظˆط¨ظٹط§ظ†ط§طھ ط£ظˆظ„ظٹط§ط، ط§ظ„ط£ظ…ظˆط±';
    }
    if (app.isProgramEntry) {
      return 'طھظ†ط¸ظٹظ… ط§ظ„ظ†ظˆط§ط© ط§ظ„ط¹ظ„ط§ط¬ظٹط© ظˆط§ظ„ط£ظ‡ط¯ط§ظپ ط§ظ„ط³ط±ظٹط±ظٹط©';
    }
    return title;
  }

  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.sanadOwner:
        return 'ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸ط¦â€™ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ ط·آ·ط¢آ¸ط·آ·ط¢آ§ط·آ¸أ¢â‚¬آ¦';
      case UserRole.centerManager:
        return 'ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ·ط¢آ± ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²';
      case UserRole.specialist:
        return 'ط·آ·ط¢آ£ط·آ·ط¢آ®ط·آ·ط¢آµط·آ·ط¢آ§ط·آ·ط¢آ¦ط·آ¸ط¸آ¹';
      case UserRole.dataEntry:
        return 'ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ·ط¢آ®ط·آ¸أ¢â‚¬â€چ ط·آ·ط¢آ¨ط·آ¸ط¸آ¹ط·آ·ط¢آ§ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ§ط·آ·ط¹آ¾';
      case UserRole.programEntry:
        return 'ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ·ط¢آ®ط·آ¸أ¢â‚¬â€چ ط·آ·ط¢آ¨ط·آ·ط¢آ±ط·آ·ط¢آ§ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¬';
      case UserRole.parent:
        return 'ط·آ¸ط«â€ ط·آ¸أ¢â‚¬â€چط·آ¸ط¸آ¹ ط·آ·ط¢آ£ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±';
      case null:
        return 'ط·آ·ط¢آ­ط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¢آ¨';
    }
  }
}

class _AccountMenuHeader extends StatelessWidget {
  const _AccountMenuHeader({
    required this.name,
    required this.roleLabel,
    required this.role,
  });

  final String name;
  final String roleLabel;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoleAvatar(role: role, name: name, radius: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
              ),
              Text(
                roleLabel,
                style: SanadText.muted(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Text(
                    'ط·آ·ط¢آ³',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: const Text(
                  'Sanad',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  context.watch<AppProvider>().currentCenter?.name ??
                      'ط·آ·ط¢آ¥ط·آ·ط¢آ¯ط·آ·ط¢آ§ط·آ·ط¢آ±ط·آ·ط¢آ© ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¹آ¾ط·آ·ط¢آ®ط·آ·ط¢آ§ط·آ·ط¢آ·ط·آ·ط¢آ¨ ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¹آ¾ط·آ·ط¢آ£ط·آ¸أ¢â‚¬طŒط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬â€چ',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = items[itemIndex];
                    return _SidebarTile(
                      item: item,
                      selected: itemIndex == index,
                      onTap: () {
                        onChanged(itemIndex);
                        if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                          Navigator.pop(context);
                        }
                      },
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

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primaryContainer
              : hovered
                  ? colorScheme.surfaceContainerHigh
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: active
                ? colorScheme.primary.withValues(alpha: .25)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            leading: Icon(
              widget.item.icon,
              size: 24,
              color:
                  active ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              widget.item.title,
              style: TextStyle(
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: active ? colorScheme.primary : null,
              ),
            ),
            onTap: widget.onTap,
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
