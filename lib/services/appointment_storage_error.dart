import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const String appointmentMigrationFile = '20260320_appointments_v1.sql';

String describeAppointmentStorageError(Object error) {
  if (_isAppointmentPermissionError(error)) {
    return 'Supabase blocked access to appointment data. Check table permissions or Row Level Security policies.';
  }
  if (_isMissingAppointmentTableError(error)) {
    return 'Appointment tables are missing in Supabase. Apply migration $appointmentMigrationFile.';
  }
  return error.toString();
}

bool isMissingAppointmentTableError(Object error) {
  return _isMissingAppointmentTableError(error);
}

bool _isMissingAppointmentTableError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42P01' || error.code == 'PGRST205') {
      return true;
    }
    final message = _joinPostgrestFields(error);
    return message.contains('appointments');
  }

  final message = error.toString().toLowerCase();
  return message.contains('appointments') &&
      (message.contains('does not exist') ||
          message.contains('could not find the table') ||
          message.contains('relation'));
}

bool _isAppointmentPermissionError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return true;
    }
    final message = _joinPostgrestFields(error);
    return message.contains('permission denied') ||
        message.contains('row-level security') ||
        message.contains('violates row-level security policy');
  }

  final message = error.toString().toLowerCase();
  return message.contains('permission denied') ||
      message.contains('row-level security');
}

String _joinPostgrestFields(PostgrestException error) {
  return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
      .toLowerCase();
}
