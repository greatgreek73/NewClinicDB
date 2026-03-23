import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

import 'appointment_service.dart';
import 'patient_payment_service.dart';
import 'supabase_client.dart';
import 'waiting_room_service.dart';

class PatientProfileDraft {
  final String name;
  final String surname;
  final String? phone;
  final String? city;
  final String? gender;
  final int? age;
  final String? photoUrl;

  const PatientProfileDraft({
    required this.name,
    required this.surname,
    this.phone,
    this.city,
    this.gender,
    this.age,
    this.photoUrl,
  });

  void validate() {
    if (name.trim().isEmpty) {
      throw StateError('Patient name is required.');
    }
    if (surname.trim().isEmpty) {
      throw StateError('Patient surname is required.');
    }
    if (age != null && age! <= 0) {
      throw StateError('Patient age must be greater than 0.');
    }
  }

  Map<String, dynamic> toUpdatePayload() {
    validate();
    return <String, dynamic>{
      'name': name.trim(),
      'surname': surname.trim(),
      'search_key': _buildPatientSearchKey(surname),
      'phone': _normalizeOptionalText(phone),
      'city': _normalizeOptionalText(city),
      'gender': _normalizeOptionalText(gender),
      'age': age,
      'photo_url': _normalizeOptionalText(photoUrl),
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class PatientDeleteCheck {
  final int paymentsCount;
  final int treatmentsCount;
  final int appointmentsCount;
  final int waitingRoomEntriesCount;

  const PatientDeleteCheck({
    required this.paymentsCount,
    required this.treatmentsCount,
    required this.appointmentsCount,
    required this.waitingRoomEntriesCount,
  });

  bool get hasBlockingDependencies =>
      paymentsCount > 0 || treatmentsCount > 0 || appointmentsCount > 0;

  bool get willRemoveWaitingRoomEntries => waitingRoomEntriesCount > 0;

  List<String> get blockingReasons {
    final reasons = <String>[];
    if (paymentsCount > 0) {
      reasons.add(
        paymentsCount == 1
            ? '1 payment is stored in the patient card.'
            : '$paymentsCount payments are stored in the patient card.',
      );
    }
    if (treatmentsCount > 0) {
      reasons.add(
        treatmentsCount == 1
            ? '1 treatment is linked to this patient.'
            : '$treatmentsCount treatments are linked to this patient.',
      );
    }
    if (appointmentsCount > 0) {
      reasons.add(
        appointmentsCount == 1
            ? '1 appointment is linked to this patient.'
            : '$appointmentsCount appointments are linked to this patient.',
      );
    }
    return reasons;
  }
}

class PatientProfileService {
  static const _patientsTable = 'patients';
  static const _treatmentsTable = 'treatments';

  const PatientProfileService();

  Future<Map<String, dynamic>?> loadPatient(String patientId) async {
    final client = maybeSupabaseClient;
    final normalizedId = patientId.trim();
    if (client == null || normalizedId.isEmpty) {
      return null;
    }

    final response =
        await client
            .from(_patientsTable)
            .select()
            .eq('id', normalizedId)
            .maybeSingle();
    if (response == null) {
      return null;
    }
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> updatePatientProfile(
    String patientId,
    PatientProfileDraft draft,
  ) async {
    final client = maybeSupabaseClient;
    final normalizedId = patientId.trim();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    if (normalizedId.isEmpty) {
      throw StateError('Patient id is required.');
    }

    await client
        .from(_patientsTable)
        .update(draft.toUpdatePayload())
        .eq('id', normalizedId);
  }

  Future<PatientDeleteCheck> inspectDeleteDependencies(
    String patientId, {
    Map<String, dynamic>? currentPatientData,
  }) async {
    final client = maybeSupabaseClient;
    final normalizedId = patientId.trim();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    if (normalizedId.isEmpty) {
      throw StateError('Patient id is required.');
    }

    final patientData = currentPatientData ?? await loadPatient(normalizedId);
    final paymentsCount = parsePatientPayments(patientData?['payments']).length;
    final treatmentsCount = await client
        .from(_treatmentsTable)
        .count()
        .eq('patient_id', normalizedId);
    final appointmentsCount = await _countAppointmentsOrZero(
      client,
      normalizedId,
    );
    final waitingRoomEntriesCount = await _countWaitingRoomEntriesOrZero(
      client,
      normalizedId,
    );

    return PatientDeleteCheck(
      paymentsCount: paymentsCount,
      treatmentsCount: treatmentsCount,
      appointmentsCount: appointmentsCount,
      waitingRoomEntriesCount: waitingRoomEntriesCount,
    );
  }

  Future<void> deletePatient(
    String patientId, {
    bool removeWaitingRoomEntries = false,
  }) async {
    final client = maybeSupabaseClient;
    final normalizedId = patientId.trim();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    if (normalizedId.isEmpty) {
      throw StateError('Patient id is required.');
    }

    if (removeWaitingRoomEntries) {
      await _deleteWaitingRoomEntriesOrIgnore(client, normalizedId);
    }

    await client.from(_patientsTable).delete().eq('id', normalizedId);
  }

  Future<int> _countWaitingRoomEntriesOrZero(
    SupabaseClient client,
    String patientId,
  ) async {
    try {
      return await client
          .from(WaitingRoomService.entriesTable)
          .count()
          .eq('patient_id', patientId);
    } catch (error) {
      if (_isMissingWaitingRoomTableError(error)) {
        return 0;
      }
      rethrow;
    }
  }

  Future<int> _countAppointmentsOrZero(
    SupabaseClient client,
    String patientId,
  ) async {
    try {
      return await client
          .from(AppointmentService.appointmentsTable)
          .count()
          .eq('patient_id', patientId);
    } catch (error) {
      if (_isMissingAppointmentsTableError(error)) {
        return 0;
      }
      rethrow;
    }
  }

  Future<void> _deleteWaitingRoomEntriesOrIgnore(
    SupabaseClient client,
    String patientId,
  ) async {
    try {
      await client
          .from(WaitingRoomService.entriesTable)
          .delete()
          .eq('patient_id', patientId);
    } catch (error) {
      if (_isMissingWaitingRoomTableError(error)) {
        return;
      }
      rethrow;
    }
  }

  bool _isMissingWaitingRoomTableError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        return true;
      }
      final message =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      return message.contains('waiting_room_entries') &&
          (message.contains('does not exist') ||
              message.contains('could not find the table') ||
              message.contains('relation'));
    }

    final message = error.toString().toLowerCase();
    return message.contains('waiting_room_entries') &&
        (message.contains('does not exist') ||
            message.contains('could not find the table') ||
            message.contains('relation'));
  }

  bool _isMissingAppointmentsTableError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        return true;
      }
      final message =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      return message.contains('appointments') &&
          (message.contains('does not exist') ||
              message.contains('could not find the table') ||
              message.contains('relation'));
    }

    final message = error.toString().toLowerCase();
    return message.contains('appointments') &&
        (message.contains('does not exist') ||
            message.contains('could not find the table') ||
            message.contains('relation'));
  }
}

String _buildPatientSearchKey(String surname) {
  return surname.trim().toLowerCase();
}

String? _normalizeOptionalText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
