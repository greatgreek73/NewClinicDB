import '../models/waiting_room.dart';
import 'id_generator.dart';
import 'supabase_client.dart';
import 'waiting_room_storage_error.dart';

class WaitingRoomReasonService {
  static const reasonsTable = 'waiting_room_reasons';

  const WaitingRoomReasonService();

  Stream<List<WaitingRoomReason>> watchActiveReasons() {
    final client = maybeSupabaseClient;
    if (client == null) {
      return Stream.value(const <WaitingRoomReason>[]);
    }

    return client.from(reasonsTable).stream(primaryKey: ['id']).map((rows) {
      final reasons =
          rows
              .map(
                (row) =>
                    WaitingRoomReason.fromRow(Map<String, dynamic>.from(row)),
              )
              .where((reason) => reason.isActive)
              .toList();
      _sortReasons(reasons);
      return reasons;
    });
  }

  Stream<List<WaitingRoomReason>> watchAllReasons() {
    final client = maybeSupabaseClient;
    if (client == null) {
      return Stream.value(const <WaitingRoomReason>[]);
    }

    return client.from(reasonsTable).stream(primaryKey: ['id']).map((rows) {
      final reasons =
          rows
              .map(
                (row) =>
                    WaitingRoomReason.fromRow(Map<String, dynamic>.from(row)),
              )
              .toList();
      _sortReasons(reasons);
      return reasons;
    });
  }

  Future<WaitingRoomReason?> loadReason(String reasonId) async {
    try {
      final client = maybeSupabaseClient;
      final normalizedId = reasonId.trim();
      if (client == null || normalizedId.isEmpty) {
        return null;
      }

      final response =
          await client
              .from(reasonsTable)
              .select()
              .eq('id', normalizedId)
              .maybeSingle();
      if (response is! Map) return null;
      return WaitingRoomReason.fromRow(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (error) {
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<void> addReason(String label) async {
    try {
      final client = maybeSupabaseClient;
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }

      final normalizedLabel = normalizeWaitingRoomReasonLabel(label);
      if (normalizedLabel == null) {
        throw StateError('Reason label cannot be empty');
      }

      final existing = await _loadAllReasons();
      final maxSortOrder =
          existing.isEmpty
              ? 0
              : existing
                  .map((reason) => reason.sortOrder)
                  .reduce((a, b) => a > b ? a : b);
      final now = DateTime.now().toUtc().toIso8601String();

      await client.from(reasonsTable).insert({
        'id': generateTextId('waiting_reason'),
        'label': normalizedLabel,
        'sort_order': maxSortOrder + 1,
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      });
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<void> renameReason(String id, String label) async {
    try {
      final client = maybeSupabaseClient;
      final normalizedId = id.trim();
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }
      if (normalizedId.isEmpty) {
        throw StateError('Reason id is required');
      }

      final normalizedLabel = normalizeWaitingRoomReasonLabel(label);
      if (normalizedLabel == null) {
        throw StateError('Reason label cannot be empty');
      }

      await client
          .from(reasonsTable)
          .update({
            'label': normalizedLabel,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', normalizedId);
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<void> deactivateReason(String id) async {
    try {
      final client = maybeSupabaseClient;
      final normalizedId = id.trim();
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }
      if (normalizedId.isEmpty) {
        throw StateError('Reason id is required');
      }

      await client
          .from(reasonsTable)
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', normalizedId);
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<List<WaitingRoomReason>> _loadAllReasons() async {
    try {
      final client = maybeSupabaseClient;
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }

      final response = await client.from(reasonsTable).select();
      final reasons =
          (response as List)
              .map(
                (row) => WaitingRoomReason.fromRow(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList();
      _sortReasons(reasons);
      return reasons;
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  void _sortReasons(List<WaitingRoomReason> reasons) {
    reasons.sort((left, right) {
      final sortCompare = left.sortOrder.compareTo(right.sortOrder);
      if (sortCompare != 0) return sortCompare;
      return left.label.toLowerCase().compareTo(right.label.toLowerCase());
    });
  }
}
