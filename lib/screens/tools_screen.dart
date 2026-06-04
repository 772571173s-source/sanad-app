import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'programs_screen.dart';
import 'reports_screen.dart';
import 'staff_screen.dart';
import 'students_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String selected = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          children: [
            _ToolCard(
              icon: Icons.search,
              title: 'بحث عن طالب',
              subtitle: '${app.students.length} طالب في المركز',
              selected: selected == 'students',
              onTap: () => setState(() => selected = 'students'),
            ),
            _ToolCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'طباعة تقرير',
              subtitle: 'تقارير PDF للطلاب',
              selected: selected == 'reports',
              onTap: () => setState(() => selected = 'reports'),
            ),
            _ToolCard(
              icon: Icons.extension_outlined,
              title: 'إدارة البرامج',
              subtitle: '${app.programs.length} برنامج علاجي',
              selected: selected == 'programs',
              onTap: () => setState(() => selected = 'programs'),
            ),
            _ToolCard(
              icon: Icons.manage_accounts_outlined,
              title: 'إنشاء حسابات',
              subtitle: '${app.staff.length} حساب موظف ومدير',
              selected: selected == 'staff',
              onTap: () => setState(() => selected = 'staff'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (selected == 'students') const StudentsScreen(),
        if (selected == 'reports') const ReportsScreen(),
        if (selected == 'programs') const ProgramsScreen(),
        if (selected == 'staff') const StaffScreen(),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(selected ? Icons.check_circle : Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
