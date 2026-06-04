import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class OwnerSupportScreen extends StatelessWidget {
  const OwnerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.centers.isEmpty) {
      return const EmptyState(
          icon: Icons.support_agent,
          title: 'لا توجد مراكز',
          message: 'أضف مركزًا أولًا حتى يظهر في شاشة المساعدة.');
    }
    return ResponsiveGrid(
      children: app.centers.map((center) {
        return AppCard(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text(center.name),
            subtitle: Text(center.isActive ? 'مركز فعال' : 'مركز متوقف'),
            trailing: const Text('مشاهدة'),
            onTap: () => app.switchCenter(center),
          ),
        );
      }).toList(),
    );
  }
}
