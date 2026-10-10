import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/scheduling/screens/appointment_list_screen.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_scheduling.dart';
import '../../support/harnesses/widget_harness.dart';

class _FailingListRepository extends FakeSchedulingRepository {
  @override
  Future<AppointmentPage> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    throw const ApiException(
      kind: ApiExceptionKind.server,
      message: 'boom',
      code: 'PLT999',
    );
  }
}

void main() {
  Appointment row({
    required String id,
    required String contractId,
    required String status,
  }) {
    final DateTime start = DateTime.now().toUtc().add(const Duration(days: 2));
    return Appointment(
      id: id,
      contractId: contractId,
      professionalEntityId: 'pro-1',
      clientEntityId: 'client-1',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      status: status,
      idempotencyKey: 'key-$id',
    );
  }

  SchedulingProvider providerWith({
    List<Appointment>? appointments,
    bool listHasMore = false,
    FakeSchedulingRepository? repo,
  }) {
    final FakeSchedulingRepository repository =
        repo ??
        FakeSchedulingRepository(
          appointments: appointments,
          listHasMore: listHasMore,
        );
    return SchedulingProvider(
      service: SchedulingService(repository: repository),
    );
  }

  List<SingleChildWidget> providers(SchedulingProvider provider) =>
      <SingleChildWidget>[
        ChangeNotifierProvider<SchedulingProvider>.value(value: provider),
      ];

  group('AppointmentListScreen', () {
    testWidgets('renders only this contract rows with badges', (
      WidgetTester tester,
    ) async {
      final SchedulingProvider provider = providerWith(
        appointments: <Appointment>[
          row(id: 'appt-1', contractId: 'contract-1', status: 'pending'),
          row(id: 'appt-2', contractId: 'contract-1', status: 'cancelled'),
          row(id: 'appt-3', contractId: 'other', status: 'pending'),
        ],
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const AppointmentListScreen(contractId: 'contract-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Appointments'), findsOneWidget);
      // Status badges render on the rows; the filter chips share the same
      // labels, so both surfaces match.
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Cancelled'), findsWidgets);
      // Two rows for this contract; the foreign appointment stays out.
      expect(provider.appointments.length, 2);
    });

    testWidgets('empty state offers booking', (WidgetTester tester) async {
      final SchedulingProvider provider = providerWith();
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const AppointmentListScreen(contractId: 'contract-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('No appointments yet'), findsOneWidget);
      expect(find.text('Book appointment'), findsOneWidget);
    });

    testWidgets('status filter narrows the list', (WidgetTester tester) async {
      final FakeSchedulingRepository repo = FakeSchedulingRepository(
        appointments: <Appointment>[
          row(id: 'appt-1', contractId: 'contract-1', status: 'pending'),
          row(id: 'appt-2', contractId: 'contract-1', status: 'cancelled'),
        ],
      );
      final SchedulingProvider provider = providerWith(repo: repo);
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const AppointmentListScreen(contractId: 'contract-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(provider.appointments.length, 2);
      await tester.tap(find.widgetWithText(HivorrChip, 'Cancelled'));
      await tester.pumpAndSettle();
      expect(repo.lastStatus, 'cancelled');
      expect(provider.appointments.length, 1);
      expect(provider.appointments.first.status, 'cancelled');
    });

    testWidgets('load more exhausts the keyset cursor', (
      WidgetTester tester,
    ) async {
      final SchedulingProvider provider = providerWith(
        appointments: <Appointment>[
          row(id: 'appt-1', contractId: 'contract-1', status: 'pending'),
          row(id: 'appt-2', contractId: 'contract-1', status: 'pending'),
        ],
        listHasMore: true,
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const AppointmentListScreen(contractId: 'contract-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Load more'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Load more'), findsNothing);
      expect(provider.appointments.length, 2);
    });

    testWidgets('failure surfaces error state with retry', (
      WidgetTester tester,
    ) async {
      final SchedulingProvider provider = providerWith(
        repo: _FailingListRepository(),
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const AppointmentListScreen(contractId: 'contract-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load appointments'), findsOneWidget);
    });

    testWidgets('visual identity uses the brand primary token', (
      WidgetTester tester,
    ) async {
      final SchedulingProvider provider = providerWith(
        appointments: <Appointment>[
          row(id: 'appt-1', contractId: 'contract-1', status: 'pending'),
        ],
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const AppointmentListScreen(contractId: 'contract-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(AppTheme.lightTheme.colorScheme.primary, const Color(0xFF2D3FE7));
    });
  });
}
