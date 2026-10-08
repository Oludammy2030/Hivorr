import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/repositories/scheduling_repository.dart';
import 'package:hivorr/data/repositories/scheduling_repository_impl.dart';

import '../../support/fakes/fake_scheduling.dart';

void main() {
  SchedulingRepository repository({
    FakeSchedulingRemoteDataSource? remote,
  }) => SchedulingRepositoryImpl(
    remote: remote ?? FakeSchedulingRemoteDataSource(),
  );

  DateTime future(int days, int hour) {
    final DateTime base = DateTime.now().toUtc().add(Duration(days: days));
    return DateTime.utc(base.year, base.month, base.day, hour);
  }

  group('SchedulingRepositoryImpl fail-fast PLT003', () {
    test('rejects weekday 7', () async {
      await expectLater(
        repository().upsertSlot(
          professionId: 'profession-1',
          weekday: 7,
          startTime: '09:00:00',
          endTime: '12:00:00',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects start >= end', () async {
      await expectLater(
        repository().upsertSlot(
          professionId: 'profession-1',
          weekday: 1,
          startTime: '12:00:00',
          endTime: '12:00:00',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects duration 5 and 600', () async {
      for (final int duration in <int>[5, 600]) {
        await expectLater(
          repository().upsertSlot(
            professionId: 'profession-1',
            weekday: 1,
            startTime: '09:00:00',
            endTime: '12:00:00',
            slotDurationMin: duration,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
          ),
        );
      }
    });

    test('rejects bad timezone', () async {
      await expectLater(
        repository().upsertSlot(
          professionId: 'profession-1',
          weekday: 1,
          startTime: '09:00:00',
          endTime: '12:00:00',
          timezone: '123',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects past starts_at', () async {
      final DateTime past = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await expectLater(
        repository().bookAppointment(
          contractId: 'contract-1',
          startsAt: past,
          endsAt: past.add(const Duration(hours: 1)),
          idempotencyKey: 'key-1',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects ends <= starts', () async {
      final DateTime start = future(2, 10);
      await expectLater(
        repository().bookAppointment(
          contractId: 'contract-1',
          startsAt: start,
          endsAt: start,
          idempotencyKey: 'key-1',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects window longer than 24h', () async {
      final DateTime start = future(2, 9);
      await expectLater(
        repository().bookAppointment(
          contractId: 'contract-1',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 25)),
          idempotencyKey: 'key-1',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects long cancel reason', () async {
      await expectLater(
        repository().cancelAppointment('appt-1', reason: 'a' * 501),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects invalid status filter', () async {
      await expectLater(
        repository().listAppointments(
          contractId: 'contract-1',
          status: 'teleported',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });
  });

  group('SchedulingRepositoryImpl write then re-read', () {
    test('book returns the authoritative row via get', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();
      final Appointment created =
          await SchedulingRepositoryImpl(remote: remote).bookAppointment(
            contractId: 'contract-1',
            startsAt: future(2, 10),
            endsAt: future(2, 11),
            idempotencyKey: 'key-abc',
          );
      expect(created.status, 'pending');
      expect(remote.bookCalls, 1);
      expect(remote.getCalls, 1);
    });

    test('same idempotency key replays the same row', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();
      final SchedulingRepository repo = SchedulingRepositoryImpl(
        remote: remote,
      );
      final Appointment first = await repo.bookAppointment(
        contractId: 'contract-1',
        startsAt: future(2, 10),
        endsAt: future(2, 11),
        idempotencyKey: 'key-same',
      );
      final Appointment second = await repo.bookAppointment(
        contractId: 'contract-1',
        startsAt: future(2, 10),
        endsAt: future(2, 11),
        idempotencyKey: 'key-same',
      );
      expect(second.id, first.id);
    });

    test('upsert re-reads the template list', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();
      final slots = await SchedulingRepositoryImpl(
        remote: remote,
      ).upsertSlot(
        professionId: 'profession-1',
        weekday: 1,
        startTime: '09:00:00',
        endTime: '12:00:00',
      );
      expect(slots, isNotEmpty);
      expect(remote.upsertCalls, 1);
      expect(remote.listSlotsCalls, 1);
    });
  });
}
