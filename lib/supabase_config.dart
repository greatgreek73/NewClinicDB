import 'supabase_config.local.dart' as local;

class SupabaseConfig {
  static const _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url {
    if (_urlFromDefine.isNotEmpty) return _urlFromDefine;
    return local.localSupabaseUrl;
  }

  static String get anonKey {
    if (_anonKeyFromDefine.isNotEmpty) return _anonKeyFromDefine;
    return local.localSupabaseAnonKey;
  }
}
