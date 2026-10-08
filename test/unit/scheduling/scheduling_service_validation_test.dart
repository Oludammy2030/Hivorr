import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/repositories/scheduling_repository_impl.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';

import '../../support/fakes/fake_scheduling.dart';

void main() {
  group('SchedulingService validators mirror server CHECKs', () {
    test('validateWeekday accepts 0-6 only', () {
      for (int day = 0; day <= 6; day++) {
        expect(SchedulingService.validateWeekday(day), isTrue);
      }
      expect(SchedulingService.validateWeekday(-1), isFalse);
      expect(SchedulingService.validateWeekday(7), isFalse);
      expect(SchedulingService.validateWeekday(null), isFalse);
    });

    test('validateTimeRange requires start < end', () {
      expect(
        SchedulingService.validateTimeRange('09:00:00', '12:00:00'),
        isTrue,
      );
      expect(
        SchedulingService.validateTimeRange('12:00:00', '12:00:00'),
        isFalse,
      );
      expect(
        SchedulingService.validateTimeRange('14:00:00', '12:00:00'),
        isFalse,
      );
      expect(SchedulingService.validateTimeRange('', '12:00:00'), isFalse);
      expect(SchedulingService.validateTimeRange(null, '12:00:00'), isFalse);
    });

    test('validateDuration enforces 15-480', () {
      expect(SchedulingService.validateDuration(15), isTrue);
      expect(SchedulingService.validateDuration(60), isTrue);
      expect(SchedulingService.validateDuration(480), isTrue);
      expect(SchedulingService.validateDuration(5), isFalse);
      expect(SchedulingService.validateDuration(600), isFalse);
      expect(SchedulingService.validateDuration(null), isFalse);
    });

    test('validateTimezone enforces IANA shape', () {
      expect(
        SchedulingService.validateTimezone('Africa/Lagos'),
        isTrue,
      );
      expect(SchedulingService.validateTimezone('Europe/London'), isTrue);
      expect(SchedulingService.validateTimezone(''), isFalse);
      expect(SchedulingService.validateTimezone('123'), isFalse);
      expect(SchedulingService.validateTimezone(null), isFalse);
    });

    test('validateWindow enforces future start, ordering, 24h cap', () {
      final DateTime start = DateTime.now().toUtc().add(
        const Duration(days: 2),
      );
      final DateTime end = start.add(const Duration(hours: 1));
      expect(SchedulingService.validateWindow(start, end), isTrue);
      expect(SchedulingService.validateWindow(end, start), isFalse);
      expect(
        SchedulingService.validateWindow(
          DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        isFalse,
      );
      expect(
        SchedulingService.validateWindow(
          start,
          start.add(const Duration(hours: 25)),
        ),
        isFalse,
      );
      expect(SchedulingService.validateWindow(null, end), isFalse);
    });

    test('validateReason caps at 500 chars', () {
      expect(SchedulingService.validateReason(null), isTrue);
      expect(SchedulingService.validateReason('Running late'), isTrue);
      expect(SchedulingService.validateReason('a' * 500), isTrue);
      expect(SchedulingService.validateReason('a' * 501), isFalse);
    });

    test('weekdayLabel maps 0 to Sun', () {
      expect(SchedulingService.weekdayLabel(0), 'Sun');
      expect(SchedulingService.weekdayLabel(1), 'Mon');
      expect(SchedulingService.weekdayLabel(6), 'Sat');
    });
  });

  group('SchedulingService idempotency orchestration', () {
    test('book mints a key when the caller omits one', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();
      final SchedulingService service = SchedulingService(
        repository: SchedulingRepositoryImpl(remote: remote),
      );
      final DateTime start = DateTime.now().toUtc().add(
        const Duration(days: 2),
      );
      final Appointment created = await service.bookAppointment(
        contractId: 'contract-1',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
      );
      expect(created.idempotencyKey, isNotNull);
      expect(created.idempotencyKey, isNotEmpty);
    });

    test('book passes a caller key through verbatim', () async {
      final FakeSchedulingRemoteDataSource remote =
          FakeSchedulingRemoteDataSource();
      final SchedulingService service = SchedulingService(
        repository: SchedulingRepositoryImpl(remote: remote),
      );
      final DateTime start = DateTime.now().toUtc().add(
        const Duration(days: 2),
      );
      final Appointment created = await service.bookAppointment(
        contractId: 'contract-1',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        idempotencyKey: 'caller-key-1',
      );
      expect(created.idempotencyKey, 'caller-key-1');
    });
  });
}
