import 'package:flutter/material.dart';
import 'package:hivorr/shared/shared.dart';

/// Demo gallery showcasing every design-system primitive.
///
/// This is a standalone demo (not part of the `lib/shared` library) so the
/// team can visually verify the design system. Run with:
/// `flutter run -t lib/gallery/main.dart`
class Gallery extends StatelessWidget {
  const Gallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hivorr Design System')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HivorrSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _section(
              'Buttons',
              Wrap(
                spacing: HivorrSpacing.sm,
                runSpacing: HivorrSpacing.sm,
                children: <Widget>[
                  HivorrButton(label: 'Primary', onPressed: () {}),
                  HivorrButton(
                    label: 'Secondary',
                    variant: HivorrButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  HivorrButton(
                    label: 'Outline',
                    variant: HivorrButtonVariant.outline,
                    onPressed: () {},
                  ),
                  HivorrButton(
                    label: 'Text',
                    variant: HivorrButtonVariant.text,
                    onPressed: () {},
                  ),
                  HivorrButton(label: 'Loading', isLoading: true, onPressed: () {}),
                  HivorrButton(label: 'Disabled', onPressed: null),
                ],
              ),
            ),
            _section(
              'Text Field',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HivorrTextField(label: 'Email', hint: 'you@example.com'),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrTextField(
                    label: 'Password',
                    hint: 'secret',
                    obscureText: true,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrTextField(
                    label: 'With error',
                    errorText: 'This field is required',
                  ),
                ],
              ),
            ),
            _section(
              'Chips',
              Wrap(
                spacing: HivorrSpacing.sm,
                children: <Widget>[
                  HivorrChip(
                    label: 'Selected',
                    isSelected: true,
                    onSelected: (_) {},
                  ),
                  HivorrChip(label: 'Unselected', onSelected: (_) {}),
                  HivorrChip(label: 'Dismissible', onDismissed: () {}),
                ],
              ),
            ),
            _section(
              'Badges',
              Wrap(
                spacing: HivorrSpacing.sm,
                children: HivorrBadgeVariant.values
                    .map(
                      (HivorrBadgeVariant v) =>
                          HivorrBadge(label: v.name, variant: v),
                    )
                    .toList(),
              ),
            ),
            _section(
              'Avatar',
              Row(
                children: <Widget>[
                  HivorrAvatar(name: 'John Doe'),
                  const SizedBox(width: HivorrSpacing.sm),
                  HivorrAvatar(name: 'Ada'),
                  const SizedBox(width: HivorrSpacing.sm),
                  HivorrAvatar(name: ''),
                ],
              ),
            ),
            _section(
              'Card',
              HivorrCard(
                child: const Padding(
                  padding: EdgeInsets.all(HivorrSpacing.sm),
                  child: Text('Tappable card surface'),
                ),
                onTap: () {},
              ),
            ),
            _section(
              'States',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HivorrLoadingState(message: 'Loading…'),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrEmptyState(
                    title: 'No items',
                    subtitle: 'Add your first item',
                    actionButton:
                        HivorrButton(label: 'Add', onPressed: () {}),
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrErrorState(
                    message: 'Failed to load',
                    onRetry: () {},
                  ),
                ],
              ),
            ),
            _section(
              'List Tile',
              HivorrListTile(
                title: 'Title',
                subtitle: 'Subtitle',
                leading: const Icon(Icons.star),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
            _section(
              'Section Header',
              HivorrSectionHeader(
                title: 'Section',
                action: HivorrButton(label: 'Action', onPressed: () {}),
              ),
            ),
            _section(
              'Overlays (tap to preview)',
              Wrap(
                spacing: HivorrSpacing.sm,
                runSpacing: HivorrSpacing.sm,
                children: <Widget>[
                  HivorrButton(
                    label: 'Show Dialog',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => HivorrDialog(
                        title: 'Title',
                        content: const Text('Dialog content goes here.'),
                        actions: <Widget>[
                          HivorrButton(label: 'OK', onPressed: () {}),
                        ],
                      ),
                    ),
                  ),
                  HivorrButton(
                    label: 'Show Bottom Sheet',
                    onPressed: () => HivorrBottomSheet.show<void>(
                      context: context,
                      title: 'Sheet',
                      child: const Text('Bottom sheet body content.'),
                    ),
                  ),
                  HivorrButton(
                    label: 'Show Snackbar',
                    variant: HivorrButtonVariant.outline,
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      HivorrSnackbar.show(
                        context,
                        message: 'Saved successfully',
                        variant: HivorrSnackbarVariant.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _section('Divider', const HivorrDivider()),
            _section(
              'Formatters',
              const Text(
                '₦1,500.00  •  2.4 MB  •  26 Aug 2026  •  3 hours ago',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrSectionHeader(title: title),
        const SizedBox(height: HivorrSpacing.sm),
        child,
        const SizedBox(height: HivorrSpacing.xl),
      ],
    );
  }
}
