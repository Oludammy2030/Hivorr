import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/scheduling/widgets/appointment_status_badge.dart';
import 'package:provider/provider.dart';

/// Per-contract appointment list (EP-03-14 management surface).
///
/// `GET /contracts/:id/appointments`. Renders the keyset-paginated
/// appointments for [contractId] in server order (verbatim) with a status
/// filter row, pull-to-refresh, and a `Load more` footer gated by
/// `hasMore`. Rows navigate to `appointmentDetail(id)`; the empty state
/// carries a `Book appointment` action. Tokens only (`AGENT.md` Rule 5).
class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key, required this.contractId});

  /// The `service_contracts.id` whose appointments are listed.
  final String contractId;

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  static const List<String?> _filters = <String?>[
    null,
    'pending',
    'confirmed',
    'completed',
    'cancelled',
    'rescheduled',
  ];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  Future<void> _load() => context
      .read<SchedulingProvider>()
      .loadAppointments(contractId: widget.contractId);

  Future<void> _applyFilter(String? status) => context
      .read<SchedulingProvider>()
      .loadAppointments(contractId: widget.contractId, status: status);

  Future<void> _refresh() => context
      .read<SchedulingProvider>()
      .loadAppointments(contractId: widget.contractId, refresh: true);

  String _filterLabel(String? status) {
    if (status == null) return 'All';
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: HivorrContentPane(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: HivorrSpacing.sm,
                  ),
                  child: Consumer<SchedulingProvider>(
                    builder:
                        (
                          BuildContext context,
                          SchedulingProvider provider,
                          _,
                        ) => Wrap(
                          spacing: HivorrSpacing.xs,
                          runSpacing: HivorrSpacing.xs,
                          children: <Widget>[
                            for (final String? filter in _filters)
                              HivorrChip(
                                label: _filterLabel(filter),
                                isSelected: provider.statusFilter == filter,
                                onSelected: (_) =>
                                    unawaited(_applyFilter(filter)),
                              ),
                          ],
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Consumer<SchedulingProvider>(
                  builder:
                      (
                        BuildContext context,
                        SchedulingProvider provider,
                        _,
                      ) {
                        switch (provider.loadState) {
                          case SchedulingLoadState.idle:
                          case SchedulingLoadState.loading:
                            if (provider.appointments.isEmpty) {
                              return const HivorrLoadingState(
                                message: 'Loading appointments…',
                              );
                            }
                            return _AppointmentList(
                              appointments: provider.appointments,
                              hasMore: provider.hasMore,
                              loadingMore: true,
                              onLoadMore: provider.loadMore,
                            );
                          case SchedulingLoadState.loaded:
                            if (provider.isEmpty) {
                              return HivorrEmptyState(
                                title: 'No appointments yet',
                                subtitle:
                                    'Book the first appointment for this contract.',
                                actionButton: HivorrButton(
                                  label: 'Book appointment',
                                  onPressed: () => context.push(
                                    RoutePaths.appointmentBook(
                                      widget.contractId,
                                    ),
                                  ),
                                  variant: HivorrButtonVariant.primary,
                                  isExpanded: true,
                                ),
                              );
                            }
                            return _AppointmentList(
                              appointments: provider.appointments,
                              hasMore: provider.hasMore,
                              loadingMore: false,
                              onLoadMore: provider.loadMore,
                            );
                          case SchedulingLoadState.error:
                            final ApiException? error = provider.lastError;
                            if (error?.kind == ApiExceptionKind.notFound) {
                              return const HivorrEmptyState(
                                title: 'No appointments found',
                                subtitle:
                                    'It may have been removed or you may not have access.',
                              );
                            }
                            return HivorrErrorState(
                              message: 'Could not load appointments',
                              detail: error?.message,
                              onRetry: () => unawaited(_load()),
                            );
                        }
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  final List<Appointment> appointments;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final Appointment appointment in appointments)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: _AppointmentRow(appointment: appointment),
          ),
        if (hasMore)
          TextButton(
            onPressed: loadingMore ? null : () => unawaited(onLoadMore()),
            child: Text(loadingMore ? 'Loading…' : 'Load more'),
          ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      onTap: () =>
          context.push(RoutePaths.appointmentDetail(appointment.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  HivorrFormatters.date(appointment.startsAt.toLocal()),
                  style: context.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              AppointmentStatusBadge(status: appointment.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${HivorrFormatters.dateTime(appointment.startsAt.toLocal())} → ${HivorrFormatters.time(appointment.endsAt.toLocal())}',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
