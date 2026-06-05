import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const xl = 20.0;
  static const lg = 24.0;
}

class AppRadii {
  static const card = 24.0;
  static const control = 16.0;
}

class SanadUiColors {
  static const primary = Color(0xFF0F766E);
  static const secondary = Color(0xFF38BDF8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1F2937);
  static const accentBlue = Color(0xFFE0F2FE);
  static const accentGreen = Color(0xFFDCFCE7);
  static const accentAmber = Color(0xFFFEF3C7);
}

class SanadText {
  static TextStyle? title(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.25,
            letterSpacing: 0,
          );

  static TextStyle? subtitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.35,
            letterSpacing: 0,
          );

  static TextStyle? secondary(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.45,
            letterSpacing: 0,
          );

  static TextStyle? muted(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
            letterSpacing: 0,
          );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.lg,
    this.highlight = false,
  });

  final Widget child;
  final double padding;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: highlight ? 1 : 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: highlight
              ? colorScheme.primary.withValues(alpha: .32)
              : colorScheme.outlineVariant,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    );
  }
}

class TherapyCard extends StatelessWidget {
  const TherapyCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: SanadText.subtitle(context),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.primaryContainer
        : colorScheme.secondaryContainer;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: .45)
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SanadUiColors.accentGreen,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(
              icon,
              color: SanadUiColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SanadText.muted(context)),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
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
        final columns = constraints.maxWidth > 1100
            ? 3
            : constraints.maxWidth > 720
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - (AppSpacing.md * (columns - 1))) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class RoleAvatar extends StatelessWidget {
  const RoleAvatar({
    super.key,
    required this.role,
    required this.name,
    this.radius = 22,
  });

  final UserRole? role;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final data = _roleData(role);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(radius * .8),
        border: Border.all(color: colorScheme.surface.withValues(alpha: .65)),
      ),
      child: Icon(data.icon, color: data.foreground, size: radius),
    );
  }

  _RoleAvatarData _roleData(UserRole? role) {
    switch (role) {
      case UserRole.sanadOwner:
        return const _RoleAvatarData(
          Icons.workspace_premium_outlined,
          Color(0xFFFEF3C7),
          Color(0xFF92400E),
        );
      case UserRole.centerManager:
        return const _RoleAvatarData(
          Icons.business_center_outlined,
          Color(0xFFE0F2FE),
          Color(0xFF0369A1),
        );
      case UserRole.specialist:
        return const _RoleAvatarData(
          Icons.healing_outlined,
          Color(0xFFDCFCE7),
          Color(0xFF047857),
        );
      case UserRole.parent:
        return const _RoleAvatarData(
          Icons.favorite_border,
          Color(0xFFFFE4E6),
          Color(0xFFBE123C),
        );
      case UserRole.dataEntry:
      case UserRole.programEntry:
        return const _RoleAvatarData(
          Icons.badge_outlined,
          Color(0xFFEDE9FE),
          Color(0xFF6D28D9),
        );
      case null:
        return const _RoleAvatarData(
          Icons.person_outline,
          SanadUiColors.accentBlue,
          SanadUiColors.primary,
        );
    }
  }
}

class _RoleAvatarData {
  const _RoleAvatarData(this.icon, this.background, this.foreground);

  final IconData icon;
  final Color background;
  final Color foreground;
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, required this.student, this.radius = 24});

  final Student student;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        student.photoPath.isNotEmpty && File(student.photoPath).existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasPhoto ? FileImage(File(student.photoPath)) : null,
      child: hasPhoto
          ? null
          : Text(student.name.isEmpty ? 'س' : student.name.substring(0, 1)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SanadUiColors.accentBlue,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Icon(
                icon,
                size: 34,
                color: SanadUiColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SanadText.subtitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SanadText.secondary(context),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
