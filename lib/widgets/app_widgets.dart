import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = 16});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100 ? 3 : constraints.maxWidth > 720 ? 2 : 1;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map((child) => SizedBox(width: width, child: child)).toList(),
        );
      },
    );
  }
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, required this.student, this.radius = 24});

  final Student student;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = student.photoPath.isNotEmpty && File(student.photoPath).existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasPhoto ? FileImage(File(student.photoPath)) : null,
      child: hasPhoto ? null : Text(student.name.isEmpty ? 'س' : student.name.substring(0, 1)),
    );
  }
}
