import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/localization/locale_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:provider/provider.dart';

/// Settings hub (EP-04-03).
///
/// Preferences today: appearance (theme mode) and language (locale). Security
/// and notification preferences land here as their backends connect.
/// Replaces the `/settings` placeholder for dashboard users.
class DashboardSettingsScreen extends StatefulWidget {
  const DashboardSettingsScreen({super.key});

  @override
  State<DashboardSettingsScreen> createState() =>
      _DashboardSettingsScreenState();
}

class _DashboardSettingsScreenState extends State<DashboardSettingsScreen> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const HivorrSectionHeader(title: 'Appearance'),
              HivorrCard(
                child: Column(
                  children: <Widget>[
                    for (final ThemeMode mode in ThemeMode.values)
                      _OptionRow(
                        label: _modeLabel(mode),
                        selected: _mode == mode,
                        onTap: () => setState(() => _mode = mode),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: HivorrSpacing.xl),
              const HivorrSectionHeader(title: 'Language'),
              const _LocaleCard(),
              const SizedBox(height: HivorrSpacing.xl),
              const HivorrSectionHeader(title: 'About'),
              HivorrCard(
                child: Text(
                  'Hivorr connects clients with verified professionals. Jobs, applications, hires, escrow, and disputes live in one account.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _LocaleCard extends StatelessWidget {
  const _LocaleCard();

  @override
  Widget build(BuildContext context) {
    LocaleProvider? locales;
    try {
      locales = context.watch<LocaleProvider>();
    } on Object {
      locales = null;
    }
    if (locales == null) {
      return HivorrCard(
        child: Text('English', style: context.textTheme.bodyMedium),
      );
    }
    final LocaleProvider provider = locales;
    return HivorrCard(
      child: Column(
        children: <Widget>[
          for (final Locale locale in provider.supportedLocales)
            _OptionRow(
              label: locale.toLanguageTag(),
              selected: locale == provider.currentLocale,
              onTap: () => unawaited(provider.setLocale(locale)),
            ),
        ],
      ),
    );
  }
}

/// Selectable settings row with a trailing check indicator (EP-04-03).
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: HivorrSpacing.sm,
          horizontal: HivorrSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: colors.primary)
            else
              Icon(
                Icons.circle_outlined,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
