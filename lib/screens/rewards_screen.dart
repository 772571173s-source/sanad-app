import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    final reward = app.reward;

    if (student == null) return const AppCard(child: Text('اختر طالبًا أولًا.'));
    if (reward == null) return const AppCard(child: Text('لا توجد بيانات مكافآت بعد.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          children: [
            StatTile(label: 'XP', value: '${reward.xp}', icon: Icons.bolt_outlined),
            StatTile(label: 'المستوى', value: '${reward.level}', icon: Icons.workspace_premium_outlined),
            StatTile(label: 'السلسلة اليومية', value: '${reward.dailyStreak}', icon: Icons.local_fire_department_outlined),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الشارات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _badges(reward).map((badge) => Chip(avatar: const Icon(Icons.military_tech_outlined, size: 18), label: Text(badge))).toList(),
              ),
              const SizedBox(height: 16),
              if (!app.isParent)
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(onPressed: () => _addXp(app, reward, 10), icon: const Icon(Icons.add), label: const Text('إضافة 10 XP')),
                    FilledButton.tonalIcon(onPressed: () => _addStreak(app, reward), icon: const Icon(Icons.today), label: const Text('زيادة السلسلة')),
                    FilledButton.tonalIcon(onPressed: () => _addBadge(app, reward), icon: const Icon(Icons.emoji_events_outlined), label: const Text('منح شارة')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _badges(Reward reward) {
    final badges = reward.badges.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    return badges.isEmpty ? ['بداية قوية'] : badges;
  }

  Future<void> _addXp(AppProvider app, Reward reward, int value) {
    final xp = reward.xp + value;
    return app.saveReward(Reward(id: reward.id, centerId: reward.centerId, studentId: reward.studentId, xp: xp, level: (xp ~/ 100) + 1, badges: reward.badges, dailyStreak: reward.dailyStreak));
  }

  Future<void> _addStreak(AppProvider app, Reward reward) {
    return app.saveReward(Reward(id: reward.id, centerId: reward.centerId, studentId: reward.studentId, xp: reward.xp, level: reward.level, badges: reward.badges, dailyStreak: reward.dailyStreak + 1));
  }

  Future<void> _addBadge(AppProvider app, Reward reward) {
    final badges = _badges(reward)..add('إنجاز جديد');
    return app.saveReward(Reward(id: reward.id, centerId: reward.centerId, studentId: reward.studentId, xp: reward.xp, level: reward.level, badges: badges.toSet().join(','), dailyStreak: reward.dailyStreak));
  }
}
