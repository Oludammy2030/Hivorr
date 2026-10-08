/// A weekly availability template row for a professional + profession (EP-03-14).
///
/// Mirrors `availability_slots`
/// (`supabase/migrations/20260926090001_service_scheduling_schema.sql`).
/// `weekday` spans `0 (Sunday) … 6 (Saturday)`; `startTime`/`endTime` are
/// `HH:mm:ss` wall-clock strings interpreted in [timezone] (IANA, default
/// `Africa/Lagos`); `slotDurationMin` spans `15–480`.
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports. Rows are
/// server-authoritative; helpers below are view-intent hints for display only
/// and never enforcement (`AGENT.md` Rule 4).
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.id,
    required this.entityId,
    required this.professionId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMin,
    required this.timezone,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// The slot row id.
  final String id;

  /// Owning professional (`entities.id`, always `auth.uid()` on write).
  final String entityId;

  /// Bound `professions.id`.
  final String professionId;

  /// Weekday `0 (Sunday) … 6 (Saturday)`.
  final int weekday;

  /// Window start wall-clock (`HH:mm:ss`) in [timezone].
  final String startTime;

  /// Window end wall-clock (`HH:mm:ss`) in [timezone].
  final String endTime;

  /// Booking granularity in minutes (`15–480`).
  final int slotDurationMin;

  /// IANA timezone name (display hint; `timestamptz` is truth).
  final String timezone;

  /// Soft-disable flag (inactive rows hidden from consumers).
  final bool isActive;

  /// Row timestamps (RPC-managed).
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Short weekday label for chip rows (`Mon` … `Sun`, `0 = Sunday`).
  String get weekdayLabel {
    switch (weekday) {
      case 0:
        return 'Sun';
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      default:
        return 'Day $weekday';
    }
  }

  /// Display label for the window (`09:00 – 12:00`, trims seconds).
  String get windowLabel => '${_short(startTime)} – ${_short(endTime)}';

  static String _short(String time) {
    final List<String> parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return time;
  }
}
