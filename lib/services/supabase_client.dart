import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient? get maybeSupabaseClient {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

SupabaseClient get supabaseClient {
  final client = maybeSupabaseClient;
  if (client == null) {
    throw StateError('Supabase is not initialized');
  }
  return client;
}
