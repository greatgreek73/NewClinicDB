import '../models/appointment.dart';
import 'appointment_storage_error.dart';
import 'id_generator.dart';
import 'supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

class AppointmentService {
  static const appointmentsTable = 'appointments';

  final SupabaseClient? _client;

  const AppointmentService({SupabaseClient? client}) : _client = client;

  SupabaseClient? get _resolvedClient => _client ?? maybeSupabaseClient;

  Future<List<Appointment>> listByDay(DateTime day) async {
    final client = _resolvedClient;
    if (client == null) return const <Appointment>[];

    try {
      final window = appointmentDayWindowForLocalDate(day);
      final response = await client
          .from(appointmentsTable)
          .select(
            'id,patient_id,start_at,end_at,visit_label,room_label,notes,status,created_at,updated_at,patient:patients(name,surname,phone,city)',
          )
          .gte('start_at', window.startUtc.toIso8601String())
          .lt('start_at', window.endUtc.toIso8601String())
          .order('start_at');

      final rows =
          (response as List)
              .map(
                (row) =>
                    Appointment.fromRow(Map<String, dynamic>.from(row as Map)),
              )
              .toList();
      return sortAppointmentsByStartTime(rows);
    } catch (error) {
      throw StateError(describeAppointmentStorageError(error));
    }
  }

  Future<void> create(AppointmentDraft draft) async {
    final client = _resolvedClient;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await client.from(appointmentsTable).insert({
        'id': generateTextId('appointment'),
        ...draft.toPayload(),
        'status': AppointmentStatus.scheduled.value,
        'created_at': now,
        'updated_at': now,
      });
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeAppointmentStorageError(error));
    }
  }

  Future<void> update(String appointmentId, AppointmentDraft draft) async {
    final client = _resolvedClient;
    final normalizedId = appointmentId.trim();
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }
    if (normalizedId.isEmpty) {
      throw StateError('Appointment id is required.');
    }

    try {
      await client
          .from(appointmentsTable)
          .update({
            ...draft.toPayload(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', normalizedId);
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeAppointmentStorageError(error));
    }
  }

  Future<void> setStatus(String appointmentId, AppointmentStatus status) async {
    final client = _resolvedClient;
    final normalizedId = appointmentId.trim();
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }
    if (normalizedId.isEmpty) {
      throw StateError('Appointment id is required.');
    }

    try {
      await client
          .from(appointmentsTable)
          .update({
            'status': status.value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', normalizedId);
    } catch (error) {
      throw StateError(describeAppointmentStorageError(error));
    }
  }

  Future<void> deleteFuture(Appointment appointment, {DateTime? now}) async {
    final client = _resolvedClient;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }
    if (!canDeleteFutureAppointment(appointment, now: now)) {
      throw StateError('Only future scheduled appointments can be deleted.');
    }

    try {
      await client.from(appointmentsTable).delete().eq('id', appointment.id);
    } catch (error) {
      throw StateError(describeAppointmentStorageError(error));
    }
  }
}
