import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:provider/provider.dart';

/// Hires list for one side of the engagement (EP-04-03).
///
/// [role] is `client` (My Hiring → professionals hired) or `professional`
/// (My Work → work won), sourced from the `?role=` query parameter. Status
/// filter chips, pull-to-refresh, and branded states included.
class HiresScreen extends StatefulWidget {
  const HiresScreen({super.key, required this.role});

  /// `client` or `professional`.
  final String role;

  bool get isClient => role != 'professional';

  @override
  State<HiresScreen> createState() => _HiresScreenState();
}

class _HiresScreenState extends State<HiresScreen> {
  String? _statusFilter;

  static const List<String?> _filters = <String?>[
    null,
    'pending',
    'active',
    'completed',
    'cancelled',
    'disputed',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(HiresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _statusFilter = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() => context.read<HireProvider>().loadList(
    role: widget.role,
    status: _statusFilter,
  );

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final bool isClient = widget.isClient;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isClient ? 'Hired Professionals' : 'My Work',
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: HivorrSpacing.md,
                  vertical: HivorrSpacing.xs,
                ),
                itemCount: _filters.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: HivorrSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final String? filter = _filters[i];
                  return HivorrChip(
                    label: filter == null ? 'All' : _label(filter),
                    isSelected: _statusFilter == filter,
                    onSelected: (_) {
                      setState(() => _statusFilter = filter);
                      unawaited(_load());
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: hires.isLoading && hires.hires.isEmpty
                  ? const HivorrLoadingState()
                  : hires.lastError != null && hires.hires.isEmpty
                  ? HivorrErrorState(
                      message: 'Could not load hires',
                      detail: hires.lastError!.message,
                      onRetry: () => unawaited(_load()),
                    )
                  : hires.hires.isEmpty
                  ? HivorrEmptyState(
                      title: isClient ? 'No hires yet' : 'No work yet',
                      subtitle: isClient
                          ? 'Shortlist an application and hire to start working with a professional.'
                          : 'Accepted applications become work here once a client hires you.',
                      actionButton: null,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(HivorrSpacing.md),
                        itemCount: hires.hires.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: HivorrSpacing.sm),
                        itemBuilder: (BuildContext context, int i) {
                          final Hire hire = hires.hires[i];
                          return HireCard(
                            hire: hire,
                            onTap: () => context.go(
                              RoutePaths.dashboardHireDetail(hire.id),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String status) => status[0].toUpperCase() + status.substring(1);
}
