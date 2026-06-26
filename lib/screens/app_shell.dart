import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'assignment_management_screen.dart';
import 'centers_screen.dart';
import 'clinical_assessment_wizard_screen.dart';
import 'coordinator_dashboard_screen.dart';
import 'specialist_assessment_screen.dart';
import 'dashboard_screen.dart';
import 'data_entry_screen.dart';
import 'demo_center_screen.dart';
import 'owner_support_screen.dart';
import 'parent_dashboard_screen.dart';
import 'homework_screen.dart';
import 'sessions_screen.dart';
import 'settings_hub_screen.dart';
import 'specialist_dashboard_screen.dart';
import 'staff_screen.dart';
import 'student_distribution_screen.dart';
import 'student_profile_screen.dart';
import 'students_screen.dart';
import 'therapy_structure_builder_screen.dart';
import 'reports_screen.dart';
import 'tools_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  bool lastSupportMode = false;
  bool lastDemoMode = false;

  String _currentRoleLabel(AppProvider app) {
    switch (app.user?.role) {
      case UserRole.sanadOwner: return 'مالك سند';
      case UserRole.centerManager: return 'مدير مركز';
      case UserRole.clinicalSupervisor: return 'مشرف فني';
      case UserRole.therapyProgramEntry: return 'مدخل برامج علاجية';
      case UserRole.coordinator: return 'منسق';
      case UserRole.specialist: return 'أخصائي';
      case UserRole.dataEntry: return 'مدخل بيانات';
      case UserRole.parent: return 'ولي أمر';
      default: return '';
    }
  }

  int _demoCenterIndex(AppProvider app) {
    final items = _items(app);
    for (int i = 0; i < items.length; i++) {
      if (items[i].title == 'مركز سند التجريبي') return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (lastSupportMode != app.isSupportMode) {
      index = 0;
      lastSupportMode = app.isSupportMode;
    }
    if (lastDemoMode != app.isDemoModeActive) {
      index = 0;
      lastDemoMode = app.isDemoModeActive;
    }

    final items = _items(app);
    if (index >= items.length) index = 0;

    // === INDEX PROTECTION ===
    if (items.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: _buildErrorScreen('items list is empty',
              details: 'role=${app.user?.role}'),
        ),
      );
    }
    if (index < 0 || index >= items.length) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: _buildErrorScreen('Invalid index: $index / ${items.length}',
              details:
                  'role=${app.user?.role} items=[${items.map((e) => e.title).join(', ')}]'),
        ),
      );
    }

    // Force password change overrides
    final forcePasswordChange = app.user?.forcePasswordChange == true;
    final selectedIndex = forcePasswordChange ? 0 : index;
    final selected = forcePasswordChange
        ? const _NavItem(
            'تغيير كلمة المرور',
            Icons.lock_reset,
            SettingsHubScreen(),
          )
        : items[selectedIndex];
    final selectedTitle = selected.title;
    // === SCREEN CONTENT (no AnimatedSwitcher, no Stack, no opacity transitions) ===
    // KeyedSubtree ensures clean mount/unmount per screen; Expanded gives bounded
    // constraints so inner Expanded/shrinkWrap layouts work correctly.
    final screenContent = KeyedSubtree(
      key: ValueKey('${selectedIndex}_$selectedTitle'),
      child: selected.screen,
    );

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 850;
        final hPad = mobile ? 12.0 : 20.0;
        final vPad = mobile ? 8.0 : 20.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: selectedTitle, compact: mobile),
              if (app.isSupportMode) ...[
                const SizedBox(height: AppSpacing.sm),
                _SupportModeBanner(
                  centerName: app.currentCenter?.name ?? '',
                  onExit: () async {
                    await app.exitSupportMode();
                    setState(() => index = 0);
                  },
                ),
              ],
              if (app.isDemoModeActive) ...[
                _DemoModeBanner(
                  userName: app.user?.name ?? '',
                  roleName: _currentRoleLabel(app),
                  onReturnToDemoCenter: () {
                    setState(() => index = _demoCenterIndex(app));
                  },
                  onExitToOwner: () async {
                    await app.exitDemoMode();
                    setState(() => index = 0);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: screenContent,
                ),
              ),
            ],
          ),
        );
      },
    );

    final sidebar = _Sidebar(
      items: items,
      index: index,
      onChanged: (newIndex) {
        setState(() => index = newIndex);
      },
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;

            if (wide) {
              return Row(
                children: [
                  SizedBox(width: 270, child: sidebar),
                  Expanded(child: content),
                ],
              );
            }

            return Scaffold(
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'القائمة',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
              drawer: Drawer(child: sidebar),
              body: content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message, {String? details}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(details,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontFamily: 'monospace')),
            ],
          ],
        ),
      ),
    );
  }

  List<_NavItem> _commonItems(AppProvider app, List<_NavItem> roleItems) {
    // In demo mode, always add the demo center screen for quick return
    final items = List<_NavItem>.of(roleItems);
    if (app.isDemoModeActive && !app.isOwner) {
      final hasDemoCenter = items.any((i) => i.title == 'مركز سند التجريبي');
      if (!hasDemoCenter) {
        items.add(const _NavItem(
          'مركز سند التجريبي',
          Icons.science_outlined,
          DemoCenterScreen(),
        ));
      }
    }
    return items;
  }

  List<_NavItem> _items(AppProvider app) {
    if (app.isSupportMode) {
      return [
        const _NavItem(
            'Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem(
          'الطلاب',
          Icons.groups_2_outlined,
          StudentsScreen(onOpenProfile: () => setState(() => index = 2)),
        ),
        const _NavItem(
          'ملف الطالب',
          Icons.folder_shared_outlined,
          StudentProfileScreen(),
        ),
        const _NavItem(
          'الموظفون',
          Icons.manage_accounts_outlined,
          StaffScreen(),
        ),
        const _NavItem('الأدوات', Icons.construction_outlined, ToolsScreen()),
        const _NavItem(
          'الإعدادات',
          Icons.settings_outlined,
          SettingsHubScreen(),
        ),
      ];
    }

    if (app.isOwner) {
      return const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('المراكز', Icons.business_outlined, CentersScreen()),
        _NavItem('المدراء', Icons.manage_accounts_outlined, StaffScreen()),
        _NavItem(
          'مكتبة سند العلاجية',
          Icons.schema_outlined,
          TherapyStructureBuilderScreen(),
        ),
        _NavItem(
          'التقارير الذكية',
          Icons.picture_as_pdf_outlined,
          ReportsScreen(),
        ),
        _NavItem(
          'مركز سند التجريبي',
          Icons.science_outlined,
          DemoCenterScreen(),
        ),
        _NavItem('المساعدة', Icons.support_agent, OwnerSupportScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ];
    }

    if (app.isCenterManager) {
      return _commonItems(app, [
        const _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('الطلاب', Icons.groups_2_outlined, StudentsScreen(onOpenProfile: () => setState(() => index = 2))),
        const _NavItem('ملف الطالب', Icons.folder_shared_outlined, StudentProfileScreen()),
        const _NavItem('التقارير الذكية', Icons.picture_as_pdf_outlined, ReportsScreen()),
        const _NavItem('الموظفون', Icons.manage_accounts_outlined, StaffScreen()),
        const _NavItem('الأدوات', Icons.construction_outlined, ToolsScreen()),
        const _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    if (app.isClinicalSupervisor) {
      return _commonItems(app, [
        const _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('الطلاب', Icons.groups_2_outlined, StudentsScreen(onOpenProfile: () => setState(() => index = 2))),
        const _NavItem('ملف الطالب', Icons.folder_shared_outlined, StudentProfileScreen()),
        const _NavItem('التقارير الذكية', Icons.picture_as_pdf_outlined, ReportsScreen()),
        const _NavItem('التقييم العلاجي', Icons.fact_check_outlined, ClinicalAssessmentWizardScreen(embedded: true)),
        const _NavItem('بناء الهيكل العلاجي', Icons.schema_outlined, TherapyStructureBuilderScreen()),
        const _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    if (app.isCoordinator) {
      return _commonItems(app, [
        const _NavItem('لوحة التنسيق', Icons.dashboard_outlined, CoordinatorDashboardScreen()),
        const _NavItem('توزيع الطلاب', Icons.person_add_alt_1_outlined, StudentDistributionScreen()),
        const _NavItem('إدارة الارتباطات', Icons.people_outline, AssignmentManagementScreen()),
        const _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    if (app.isSpecialist) {
      return _commonItems(app, [
        const _NavItem('لوحة الأخصائي', Icons.dashboard_outlined, SpecialistDashboardScreen()),
        _NavItem('ملف الطالب', Icons.folder_shared_outlined, StudentProfileScreen(onOpenSession: () => setState(() => index = 3))),
        const _NavItem('التقييم العلاجي', Icons.fact_check_outlined, SpecialistAssessmentScreen()),
        _NavItem('الجلسات', Icons.timer_outlined, SessionsScreen(onReturnToProfile: () => setState(() => index = 1))),
        const _NavItem('الواجبات', Icons.assignment_outlined, HomeworkScreen()),
        const _NavItem('التقارير الذكية', Icons.picture_as_pdf_outlined, ReportsScreen()),
        const _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    if (app.isDataEntry) {
      return _commonItems(app, const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('الإدخال', Icons.person_add_alt, DataEntryScreen()),
        _NavItem('الطلاب', Icons.groups_2_outlined, StudentsScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    if (app.isProgramEntry) {
      return _commonItems(app, const [
        _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        _NavItem('بناء الهيكل العلاجي', Icons.schema_outlined, TherapyStructureBuilderScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    if (app.isParent) {
      return _commonItems(app, const [
        _NavItem('لوحة ولي الأمر', Icons.family_restroom_outlined, ParentDashboardScreen()),
        _NavItem('الإعدادات', Icons.settings_outlined, SettingsHubScreen()),
      ]);
    }

    return _commonItems(app, const [
      _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
    ]);
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
      title: 'أنت الآن تساعد مركز: ${centerName.isEmpty ? '-' : centerName}',
      trailing: FilledButton.tonalIcon(
        onPressed: onExit,
        icon: const Icon(Icons.keyboard_return),
        label: const Text('العودة إلى إدارة سند'),
      ),
      child: const Text(
        'وضع المساعدة يعرض بيانات هذا المركز بصلاحيات مدير المركز مع بقاء حساب مالك سند نشطًا.',
      ),
    );
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner({
    required this.userName,
    required this.roleName,
    required this.onReturnToDemoCenter,
    required this.onExitToOwner,
  });

  final String userName;
  final String roleName;
  final VoidCallback onReturnToDemoCenter;
  final VoidCallback onExitToOwner;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 420;
        return Container(
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 64),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: .1),
            border: Border(
              bottom: BorderSide(color: Colors.orange.withValues(alpha: .3)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.science_outlined, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وضع تجريبي: $roleName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    Text(
                      'بيانات تجريبية فقط',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: .7),
                      ),
                    ),
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: onReturnToDemoCenter,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('مركز التجربة', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onExitToOwner,
                  icon: const Icon(Icons.exit_to_app, size: 16),
                  label: const Text('الخروج', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
              if (!wide) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'center') onReturnToDemoCenter();
                    if (value == 'exit') onExitToOwner();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'center',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 18),
                          SizedBox(width: 8),
                          Text('مركز التجربة', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'exit',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app, size: 18),
                          SizedBox(width: 8),
                          Text('الخروج', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final name =
        user?.name.trim().isNotEmpty == true ? user!.name : 'مستخدم سند';
    final roleLabel = _roleLabel(user?.role);
    final colorScheme = Theme.of(context).colorScheme;

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RoleAvatar(role: user?.role, name: name, radius: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  _subtitle(app, title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'الحساب',
            offset: const Offset(0, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            onSelected: (value) {
              if (value == 'logout') app.logout();
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
                  label: 'تسجيل الخروج',
                  danger: true,
                ),
              ),
            ],
            child: Icon(Icons.more_vert, color: colorScheme.primary),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(app, title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'الحساب',
          offset: const Offset(0, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          onSelected: (value) {
            if (value == 'logout') app.logout();
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
                label: 'تسجيل الخروج',
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
                const SizedBox(width: AppSpacing.sm),
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
                    Text(roleLabel, style: SanadText.muted(context)),
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
    if (hour < 12) return 'صباح الخير، $name';
    if (hour < 17) return 'أهلًا، $name';
    return 'مساء الخير، $name';
  }

  String _subtitle(AppProvider app, String title) {
    if (app.isOwner) return 'إدارة سند والتأهيل';
    if (app.isCenterManager) {
      final center = app.currentCenter?.name;
      return center == null || center.isEmpty
          ? 'إدارة المركز'
          : 'إدارة مركز $center';
    }
    if (app.isSpecialist) {
      return 'متابعة التقييمات والأهداف والجلسات العلاجية';
    }
    if (app.isClinicalSupervisor) {
      return 'مراجعة التقييمات وبناء الهيكل العلاجي ومتابعة الفريق';
    }
    if (app.isCoordinator) return 'تنظيم توزيع الحالات والجداول';
    if (app.isParent) return 'متابعة الواجبات والتقدم المنزلي';
    if (app.isDataEntry) return 'تنظيم إدخال الطلاب وبيانات أولياء الأمور';
    if (app.isProgramEntry) return 'تنظيم النواة العلاجية والأهداف السريرية';
    return title;
  }

  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.sanadOwner:
        return 'مالك سند';
      case UserRole.centerManager:
        return 'مدير مركز';
      case UserRole.clinicalSupervisor:
        return 'مشرف فني';
      case UserRole.therapyProgramEntry:
        return 'مدخل البرامج العلاجية';
      case UserRole.coordinator:
        return 'منسق';
      case UserRole.specialist:
        return 'أخصائي';
      case UserRole.dataEntry:
        return 'مدخل بيانات / سكرتارية';
      case UserRole.parent:
        return 'ولي أمر';
      case null:
        return 'حساب';
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
              Text(roleLabel, style: SanadText.muted(context)),
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
                    'س',
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
                      'إدارة سند',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
      child: Material(
        color: active
            ? colorScheme.primaryContainer
            : hovered
                ? colorScheme.surfaceContainerHigh
                : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(
              color: active
                  ? colorScheme.primary.withValues(alpha: .25)
                  : Colors.transparent,
            ),
          ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
