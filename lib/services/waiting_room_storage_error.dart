import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const String waitingRoomMigrationFile = '20260316_waiting_room_v1.sql';

String describeWaitingRoomStorageError(Object error) {
  if (_isWaitingRoomPermissionError(error)) {
    return 'Supabase blocked access to waiting room data. Check table permissions or Row Level Security policies.';
  }
  if (_isMissingWaitingRoomTableError(error)) {
    return 'Waiting room tables are missing in Supabase. Apply migration $waitingRoomMigrationFile.';
  }
  return error.toString();
}

bool _isMissingWaitingRoomTableError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42P01' || error.code == 'PGRST205') {
      return true;
    }
    final message = _joinPostgrestFields(error);
    return message.contains('waiting_room_reasons') ||
        message.contains('waiting_room_entries');
  }

  final message = error.toString().toLowerCase();
  return (message.contains('waiting_room_reasons') ||
          message.contains('waiting_room_entries')) &&
      (message.contains('does not exist') ||
          message.contains('could not find the table') ||
          message.contains('relation'));
}

bool _isWaitingRoomPermissionError(Object error) {
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
