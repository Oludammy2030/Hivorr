import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';
import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';

void main() {
  group('SchedulingMapper.slotToEntity', () {
    test('maps all fields verbatim', () {
      final AvailabilitySlot slot = SchedulingMapper.slotToEntity(
        AvailabilitySlotDto.fromJson(<String, dynamic>{
          'id': 'slot-1',
          'entity_id': 'pro-1',
          'profession_id': 'profession-1',
          'weekday': 1,
          'start_time': '09:00:00',
          'end_time': '12:00:00',
          'slot_duration_min': 60,
          'timezone': 'Africa/Lagos',
          'is_active': true,
        }),
      );
      expect(slot.id, 'slot-1');
      expect(slot.weekday, 1);
      expect(slot.weekdayLabel, 'Mon');
      expect(slot.windowLabel, '09:00 – 12:00');
      expect(slot.timezone, 'Africa/Lagos');
      expect(slot.isActive, isTrue);
    });

    test('Sunday label is Sun', () {
      const AvailabilitySlot slot = AvailabilitySlot(
        id: 's',
        entityId: 'pro-1',
        professionId: 'p-1',
        weekday: 0,
        startTime: '08:00:00',
        endTime: '10:00:00',
        slotDurationMin: 60,
        timezone: 'Africa/Lagos',
        isActive: true,
      );
      expect(slot.weekdayLabel, 'Sun');
    });
  });

  group('SchedulingMapper.appointmentToEntity', () {
    test('parses timestamptz to UTC', () {
      final Appointment appointment =
          SchedulingMapper.appointmentToEntity(
            AppointmentDto.fromJson(<String, dynamic>{
              'id': 'appt-1',
              'contract_id': 'contract-1',
              'professional_entity_id': 'pro-1',
              'client_entity_id': 'client-1',
              'starts_at': '2030-10-06T09:00:00+01:00',
              'ends_at': '2030-10-06T10:00:00+01:00',
              'status': 'pending',
            }),
          );
      expect(appointment.isActiveWindow, isTrue);
      expect(appointment.isTerminal, isFalse);
      // 09:00+01:00 == 08:00Z — wall-clock preserved across zones.
      expect(appointment.startsAt.toUtc().hour, 8);
      expect(appointment.endsAt.difference(appointment.startsAt),
          const Duration(hours: 1));
    });

    test('canReschedule/canCancel are participant + active-window hints', () {
      final Appointment appointment =
          SchedulingMapper.appointmentToEntity(
            AppointmentDto.fromJson(<String, dynamic>{
              'id': 'appt-1',
              'contract_id': 'contract-1',
              'professional_entity_id': 'pro-1',
              'client_entity_id': 'client-1',
              'starts_at': '2030-10-06T09:00:00Z',
              'ends_at': '2030-10-06T10:00:00Z',
              'status': 'pending',
            }),
          );
      expect(appointment.canReschedule('client-1'), isTrue);
      expect(appointment.canReschedule('pro-1'), isTrue);
      expect(appointment.canReschedule('stranger'), isFalse);
      expect(appointment.canCancel('client-1'), isTrue);

      final Appointment cancelled =
          SchedulingMapper.appointmentToEntity(
            AppointmentDto.fromJson(<String, dynamic>{
              'id': 'appt-2',
              'contract_id': 'contract-1',
              'professional_entity_id': 'pro-1',
              'client_entity_id': 'client-1',
              'starts_at': '2030-10-06T09:00:00Z',
              'ends_at': '2030-10-06T10:00:00Z',
              'status': 'cancelled',
            }),
          );
      expect(cancelled.canReschedule('client-1'), isFalse);
      expect(cancelled.canCancel('client-1'), isFalse);
    });
  });

  group('SchedulingMapper events + envelopes', () {
    test('eventToEntity maps verbatim', () {
      final AppointmentEvent event = SchedulingMapper.eventToEntity(
        AppointmentEventDto.fromJson(<String, dynamic>{
          'id': 'ev-1',
          'appointment_id': 'appt-1',
          'contract_id': 'contract-1',
          'event_type': 'booked',
          'from_status': null,
          'to_status': 'pending',
        }),
      );
      expect(event.eventType, 'booked');
      expect(event.toStatus, 'pending');
    });

    test('reschedule envelope advances to the replacement row', () {
      final Appointment next =
          SchedulingMapper.rescheduleEnvelopeToEntity(
            AppointmentRescheduleEnvelopeDto.fromJson(<String, dynamic>{
              'old_appointment': <String, dynamic>{
                'id': 'appt-1',
                'contract_id': 'contract-1',
                'professional_entity_id': 'pro-1',
                'client_entity_id': 'client-1',
                'starts_at': '2030-10-06T09:00:00Z',
                'ends_at': '2030-10-06T10:00:00Z',
                'status': 'rescheduled',
              },
              'new_appointment': <String, dynamic>{
                'id': 'appt-2',
                'contract_id': 'contract-1',
                'professional_entity_id': 'pro-1',
                'client_entity_id': 'client-1',
                'starts_at': '2030-10-06T14:00:00Z',
                'ends_at': '2030-10-06T15:00:00Z',
                'status': 'pending',
                'reschedule_of': 'appt-1',
              },
            }),
          );
      expect(next.id, 'appt-2');
      expect(next.rescheduleOf, 'appt-1');
      expect(next.status, 'pending');
    });

    test('list envelope preserves server slot order', () {
      final List<AvailabilitySlot> slots =
          SchedulingMapper.listEnvelopeToSlots(
            AvailabilityListEnvelopeDto.fromJson(<String, dynamic>{
              'slots': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 's1',
                  'entity_id': 'pro-1',
                  'profession_id': 'p-1',
                  'weekday': 1,
                  'start_time': '09:00:00',
                  'end_time': '12:00:00',
                  'slot_duration_min': 60,
                  'timezone': 'Africa/Lagos',
                  'is_active': true,
                },
                <String, dynamic>{
                  'id': 's2',
                  'entity_id': 'pro-1',
                  'profession_id': 'p-1',
                  'weekday': 3,
                  'start_time': '14:00:00',
                  'end_time': '17:00:00',
                  'slot_duration_min': 60,
                  'timezone': 'Africa/Lagos',
                  'is_active': true,
                },
              ],
            }),
          );
      expect(slots.map((AvailabilitySlot s) => s.id), ['s1', 's2']);
    });
  });
}
