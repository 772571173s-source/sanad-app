import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'backup_screen.dart';
import 'center_settings_screen.dart';
import 'password_screen.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: SwitchListTile(
              value: app.darkMode,
              onChanged: (_) => app.toggleTheme(),
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('الوضع الليلي'),
            ),
          ),
          const SizedBox(height: 12),
          const PasswordScreen(),
          if (app.isCenterManager) ...[
            const SizedBox(height: 12),
            const CenterSettingsScreen(),
          ],
          if (app.isOwner || app.isCenterManager) ...[
            const SizedBox(height: 12),
            const BackupScreen(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
