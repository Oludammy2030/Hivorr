// ignore_for_file: prefer_initializing_formals

import 'package:supabase_flutter/supabase_flutter.dart';

/// Counterparty fan-out for dispute lifecycle events (EP-03-17 R2).
///
/// Invokes the `dispute_notify` Edge Function once per user action (or once
/// per newly observed resolution) so the OTHER party's device renders a
/// Realtime notification. Fire-and-forget by contract: implementations throw
/// on transport failure and callers swallow — a missed push never fails the
/// dispute write itself (the server state is already authoritative).
abstract class ServiceDisputeNotifier {
  /// Notifies the counterparty of [event] (`filed`, `withdrawn`, or
  /// `resolved`) for the dispute case [caseId].
  Future<void> notifyCounterparty({
    required String caseId,
    required String event,
  });
}

/// Supabase Edge Function implementation of [ServiceDisputeNotifier].
///
/// Calls `dispute_notify` with the caller's user JWT (forwarded by the
/// functions client); the function verifies party membership via
/// `dispute_get` RLS before writing the recipient row. Never carries a
/// service-role key — that key lives only in the function's secret store.
class SupabaseServiceDisputeNotifier implements ServiceDisputeNotifier {
  SupabaseServiceDisputeNotifier({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  @override
  Future<void> notifyCounterparty({
    required String caseId,
    required String event,
  }) async {
    await _supabase.functions.invoke(
      'dispute_notify',
      body: <String, dynamic>{'case_id': caseId, 'event': event},
    );
  }
}
