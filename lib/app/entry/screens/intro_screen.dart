import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:provider/provider.dart';

/// Native first-launch welcome (entry architecture §4, §5.2).
///
/// Shown once per install on Android/iOS before anything else: three value-prop
/// pages then a "Get started" CTA that marks the intro as seen and continues to
/// `/login` (preserving any `?next=` destination the guard carried over). Pure
/// presentation; the one-time flag lives in [EntryStateProvider].
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page + 1 < _pageCount) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    unawaited(_finish());
  }

  void _skip() {
    unawaited(_finish());
  }

  /// Marks the intro as seen and continues to the login door for returning
  /// visitors, carrying the preserved `?next=` when present.
  Future<void> _finish() async {
    final EntryStateProvider entry = context.read<EntryStateProvider>();
    await entry.markIntroSeen();
    if (!mounted) {
      return;
    }
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    context.go(next == null || next.isEmpty
        ? RoutePaths.login
        : '${RoutePaths.login}?next=$next');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool isLast = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HivorrSpacing.lg,
                vertical: HivorrSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLast ? null : _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                  ),
                  child: Text(
                    'Skip',
                    style: context.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (int page) => setState(() => _page = page),
                itemBuilder: (BuildContext context, int index) => _IntroPage(
                  data: _pages[index],
                ),
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            _PageIndicator(index: _page, count: _pageCount),
            Padding(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              child: HivorrButton(
                label: isLast
                    ? 'Get started'
                    : _page == 0
                        ? "Let's begin"
                        : 'Next',
                isExpanded: true,
                size: HivorrButtonSize.large,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.data});

  final _IntroPageData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HivorrSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(data.icon, size: 96, color: colors.primary),
          const SizedBox(height: HivorrSpacing.xl),
          Text(
            data.title,
            style: context.textTheme.headlineMedium?.copyWith(
              color: colors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HivorrSpacing.md),
          Text(
            data.subtitle,
            style: context.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? colors.primary : colors.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (i != count - 1) const SizedBox(width: HivorrSpacing.xs),
        ],
      ],
    );
  }
}

class _IntroPageData {
  const _IntroPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

const List<_IntroPageData> _pages = <_IntroPageData>[
  _IntroPageData(
    icon: Icons.verified_user_outlined,
    title: 'Verified professionals',
    subtitle:
        'Every tradesperson on Hivorr passes identity and trade-proof '
        'verification before they can accept work.',
  ),
  _IntroPageData(
    icon: Icons.lock_outline,
    title: 'Escrow-protected payments',
    subtitle:
        'Funds are held safely for every project and released only once the '
        'work is delivered and accepted.',
  ),
  _IntroPageData(
    icon: Icons.handshake_outlined,
    title: 'Work backed by a record',
    subtitle:
        'A public trade history and dispute resolution keep engagements fair '
        'and accountable end to end.',
  ),
];