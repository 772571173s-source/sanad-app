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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
            height: 1.45,
            letterSpacing: 0,
          );

  static TextStyle? muted(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
            height: 1.45,
            letterSpacing: 0,
          );
}

enum SemanticAlertKind { info, warning, success, error }

class SemanticAlertTone {
  const SemanticAlertTone({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color icon;
}

SemanticAlertTone sanadAlertTone(
  BuildContext context,
  SemanticAlertKind kind,
) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (kind) {
    case SemanticAlertKind.info:
      return dark
          ? const SemanticAlertTone(
              background: Color(0xFF082F49),
              border: Color(0xFF0369A1),
              foreground: Color(0xFFE0F2FE),
              icon: Color(0xFF7DD3FC),
            )
          : const SemanticAlertTone(
              background: Color(0xFFE0F2FE),
              border: Color(0xFF7DD3FC),
              foreground: Color(0xFF0F172A),
              icon: Color(0xFF0369A1),
            );
    case SemanticAlertKind.warning:
      return dark
          ? const SemanticAlertTone(
              background: Color(0xFF451A03),
              border: Color(0xFFB45309),
              foreground: Color(0xFFFEF3C7),
              icon: Color(0xFFFBBF24),
            )
          : const SemanticAlertTone(
              background: Color(0xFFFEF3C7),
              border: Color(0xFFF59E0B),
              foreground: Color(0xFF1F2937),
              icon: Color(0xFFB45309),
            );
    case SemanticAlertKind.success:
      return dark
          ? const SemanticAlertTone(
              background: Color(0xFF052E16),
              border: Color(0xFF15803D),
              foreground: Color(0xFFDCFCE7),
              icon: Color(0xFF86EFAC),
            )
          : const SemanticAlertTone(
              background: Color(0xFFDCFCE7),
              border: Color(0xFF22C55E),
              foreground: Color(0xFF14532D),
              icon: Color(0xFF15803D),
            );
    case SemanticAlertKind.error:
      return dark
          ? const SemanticAlertTone(
              background: Color(0xFF450A0A),
              border: Color(0xFFB91C1C),
              foreground: Color(0xFFFEE2E2),
              icon: Color(0xFFFCA5A5),
            )
          : const SemanticAlertTone(
              background: Color(0xFFFEE2E2),
              border: Color(0xFFEF4444),
              foreground: Color(0xFF7F1D1D),
              icon: Color(0xFFDC2626),
            );
  }
}

class SemanticAlertCard extends StatelessWidget {
  const SemanticAlertCard({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    required this.message,
  });

  final SemanticAlertKind kind;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = sanadAlertTone(context, kind);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone.icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.foreground,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.foreground,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.xl,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 480 && trailing != null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SanadText.subtitle(context),
                          ),
                        ),
                        if (!stacked && trailing != null) trailing!,
                      ],
                    ),
                    if (stacked)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: trailing!,
                      ),
                  ],
                );
              },
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
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
    final tone = sanadAlertTone(context, SemanticAlertKind.success);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: tone.border),
            ),
            child: Icon(
              icon,
              color: tone.icon,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: SanadText.muted(context)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    final data = _roleData(context, role);
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

  _RoleAvatarData _roleData(BuildContext context, UserRole? role) {
    switch (role) {
      case UserRole.sanadOwner:
        return _avatarData(context, SemanticAlertKind.warning,
            Icons.workspace_premium_outlined);
      case UserRole.centerManager:
        return _avatarData(
            context, SemanticAlertKind.info, Icons.business_center_outlined);
      case UserRole.clinicalSupervisor:
        return _avatarData(
            context, SemanticAlertKind.success, Icons.psychology_outlined);
      case UserRole.therapyProgramEntry:
        return _avatarData(
            context, SemanticAlertKind.info, Icons.schema_outlined);
      case UserRole.coordinator:
        return _avatarData(
            context, SemanticAlertKind.warning, Icons.event_available_outlined);
      case UserRole.specialist:
        return _avatarData(
            context, SemanticAlertKind.success, Icons.healing_outlined);
      case UserRole.parent:
        return _avatarData(
            context, SemanticAlertKind.error, Icons.favorite_border);
      case UserRole.dataEntry:
        return _avatarData(
            context, SemanticAlertKind.info, Icons.badge_outlined);
      case null:
        return _avatarData(
            context, SemanticAlertKind.info, Icons.person_outline);
    }
  }

  _RoleAvatarData _avatarData(
      BuildContext context, SemanticAlertKind kind, IconData icon) {
    final tone = sanadAlertTone(context, kind);
    return _RoleAvatarData(icon, tone.background, tone.icon);
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
    final colorScheme = Theme.of(context).colorScheme;
    final hasPhoto =
        student.photoPath.isNotEmpty && File(student.photoPath).existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasPhoto ? FileImage(File(student.photoPath)) : null,
      backgroundColor: hasPhoto ? null : colorScheme.primaryContainer,
      child: hasPhoto
          ? null
          : Icon(Icons.person, size: radius * 0.9, color: colorScheme.primary),
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
    final tone = sanadAlertTone(context, SemanticAlertKind.info);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: tone.border),
              ),
              child: Icon(
                icon,
                size: 26,
                color: tone.icon,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SanadText.subtitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: SanadText.secondary(context),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ResponsiveRowHeader extends StatelessWidget {
  const ResponsiveRowHeader({
    super.key,
    required this.title,
    this.trailing,
    this.breakpoint = 500,
    this.spacing = AppSpacing.sm,
  });

  final Widget title;
  final Widget? trailing;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < breakpoint;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              if (trailing != null) ...[
                SizedBox(height: spacing),
                trailing!,
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            if (trailing != null) ...[
              SizedBox(width: spacing),
              trailing!,
            ],
          ],
        );
      },
    );
  }
}
