// Run: flutter test test/integration/marketplace/scheduling_booking_conflict_integration_test.dart
//
// EP-03-20 VP9 — Availability → booking → conflict guard → cancel → rebook.
// Composes the REAL SchedulingService over both fake seams (entity
// [FakeSchedulingRepository] + DTO [FakeSchedulingRemoteDataSource]).
// The `EXCLUDE` overlap guard is simulated server-side (`overlapNextBook`);
// the widget-level error rendering is already asserted by
// `test/widget/scheduling/scheduling_screens_test.dart:149-177`
// ("Slot taken. Pick another time." HivorrErrorState) — cited, not duplicated.

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';

import '../../support/fakes/fake_scheduling.dart';

void main() {
  group('EP-03-20 VP9 — scheduling booking conflict', () {
    test('DoD-VP9a: set availability then book inside the slot', () async {
      // Arrange: real service over the entity seam.
      final FakeSchedulingRepository repo = FakeSchedulingRepository();
      final SchedulingService service = SchedulingService(repository: repo);

      // Act: publish a Monday 09:00–12:00 window, then book inside it.
      final List<AvailabilitySlot> slots = await service.upsertSlot(
        professionId: 'profession-1',
        weekday: 1,
        startTime: '09:00:00',
        endTime: '12:00:00',
      );
      final Appointment booked = await service.bookAppointment(
        contractId: 'contract-1',
        slotId: slots.first.id,
        startsAt: DateTime.utc(2026, 10, 19, 9),
        endsAt: DateTime.utc(2026, 10, 19, 10),
        idempotencyKey: 'book-1',
      );

      // Assert: the slot was upserted once and the booking is pending.
      expect(repo.upsertCalls, 1);
      expect(
        slots.first.timezone,
        'Africa/Lagos',
        reason: 'default TZ per DB CHECK',
      );
      expect(booked.status, 'pending');
      expect(booked.slotId, slots.first.id);
      expect(booked.idempotencyKey, 'book-1');
    });

    test('DoD-VP9b: overlapping book is refused with PLT005 (server EXCLUDE '
        'guard)', () async {
      // Arrange: the server-side EXCLUDE constraint rejects the overlap —
      // simulated by the DTO seam (`overlapNextBook`), which is exactly the
      // typed conflict the widget error state renders
      // (cited: scheduling_screens_test.dart:149-177 "Slot taken. Pick
      // another time." HivorrErrorState).
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource()..overlapNextBook = true;

      // Act & Assert: the first book attempt is refused with the conflict.
      await expectLater(
        remote.bookAppointment(
          contractId: 'contract-1',
          startsAt: DateTime.utc(2026, 10, 19, 9),
          endsAt: DateTime.utc(2026, 10, 19, 10),
          idempotencyKey: 'book-overlap',
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT005')
              .having(
                (ApiException e) => e.message,
                'message',
                contains('Slot taken'),
              ),
        ),
      );
      // Exactly one attempt was made and the guard was consumed by it.
      expect(remote.bookCalls, 1);
      expect(remote.overlapNextBook, isFalse);
    });

    test('DoD-VP9c: idempotent re-book returns the same appointment', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();

      final AppointmentDto first = await remote.bookAppointment(
        contractId: 'contract-1',
        startsAt: DateTime.utc(2026, 10, 19, 9),
        endsAt: DateTime.utc(2026, 10, 19, 10),
        idempotencyKey: 'same-key',
      );
      final AppointmentDto replay = await remote.bookAppointment(
        contractId: 'contract-1',
        startsAt: DateTime.utc(2026, 10, 19, 9),
        endsAt: DateTime.utc(2026, 10, 19, 10),
        idempotencyKey: 'same-key',
      );

      // Assert: replay is a no-op read of the original row.
      expect(replay.id, first.id);
      expect(remote.bookCalls, 2, reason: 'both calls reached the seam');
      // Only one row was created — the idempotency key prevented a duplicate.
      expect(
        (await remote.listAppointments(contractId: 'contract-1')).items,
        hasLength(1),
      );
    });

    test('DoD-VP9d: cancel → rebook the window', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();

      final AppointmentDto booked = await remote.bookAppointment(
        contractId: 'contract-1',
        startsAt: DateTime.utc(2026, 10, 19, 9),
        endsAt: DateTime.utc(2026, 10, 19, 10),
        idempotencyKey: 'book-a',
      );

      // Act: cancel, then book a fresh window.
      final AppointmentDto cancelled = await remote.cancelAppointment(
        booked.id,
        reason: 'Client rescheduled.',
      );
      final AppointmentDto rebooked = await remote.bookAppointment(
        contractId: 'contract-1',
        startsAt: DateTime.utc(2026, 10, 20, 9),
        endsAt: DateTime.utc(2026, 10, 20, 10),
        idempotencyKey: 'book-b',
      );

      // Assert: cancel landed, rebook is a distinct pending row.
      expect(cancelled.status, 'cancelled');
      expect(remote.cancelCalls, 1);
      expect(rebooked.status, 'pending');
      expect(rebooked.id, isNot(booked.id));
      expect(rebooked.idempotencyKey, 'book-b');
    });

    test(
      'DoD-VP9e: cancelling a terminal appointment is refused (PLT005)',
      () async {
        final FakeSchedulingRemoteDataSource remote =
            FakeSchedulingRemoteDataSource();
        final AppointmentDto booked = await remote.bookAppointment(
          contractId: 'contract-1',
          startsAt: DateTime.utc(2026, 10, 19, 9),
          endsAt: DateTime.utc(2026, 10, 19, 10),
          idempotencyKey: 'book-x',
        );
        await remote.cancelAppointment(booked.id);

        // Act & Assert: a second cancel on the cancelled row conflicts.
        await expectLater(
          remote.cancelAppointment(booked.id),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.code,
              'code',
              'PLT005',
            ),
          ),
        );
      },
    );

    test(
      'DoD-VP9f: reschedule flips the old row and mints a new one',
      () async {
        final FakeSchedulingRemoteDataSource remote =
            FakeSchedulingRemoteDataSource();
        final AppointmentDto booked = await remote.bookAppointment(
          contractId: 'contract-1',
          startsAt: DateTime.utc(2026, 10, 19, 9),
          endsAt: DateTime.utc(2026, 10, 19, 10),
          idempotencyKey: 'book-r',
        );

        // Act: move the appointment to a new window.
        final AppointmentRescheduleEnvelopeDto envelope = await remote
            .rescheduleAppointment(
              appointmentId: booked.id,
              newStartsAt: DateTime.utc(2026, 10, 21, 14),
              newEndsAt: DateTime.utc(2026, 10, 21, 15),
              idempotencyKey: 'reschedule-r',
            );
        final AppointmentDto fresh = envelope.newAppointment;

        // Assert: the old row is terminal, the new row points back at it.
        expect(fresh.id, isNot(booked.id));
        expect(fresh.rescheduleOf, booked.id);
        expect(envelope.oldAppointment?.id, booked.id);
        expect(envelope.oldAppointment?.status, 'rescheduled');
        final AppointmentDto old = await remote.getAppointment(booked.id);
        expect(old.status, 'rescheduled');
        expect(remote.rescheduleCalls, 1);

        // Rescheduling a rescheduled row is refused (PLT005).
        await expectLater(
          remote.rescheduleAppointment(
            appointmentId: booked.id,
            newStartsAt: DateTime.utc(2026, 10, 22, 9),
            newEndsAt: DateTime.utc(2026, 10, 22, 10),
            idempotencyKey: 'reschedule-2',
          ),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.code,
              'code',
              'PLT005',
            ),
          ),
        );
      },
    );
  });
}
