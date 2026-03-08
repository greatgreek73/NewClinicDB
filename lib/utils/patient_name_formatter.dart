String formatPatientDisplayName({
  required dynamic name,
  required dynamic surname,
  String fallback = 'Patient',
}) {
  final firstName = _firstToken(name);
  final lastName = _cleanToken(surname);
  final combined = [lastName, firstName].where((v) => v.isNotEmpty).join(' ');
  return combined.isNotEmpty ? combined : fallback;
}

String _firstToken(dynamic raw) {
  final cleaned = _cleanToken(raw);
  if (cleaned.isEmpty) return '';
  return cleaned.split(RegExp(r'\s+')).first.trim();
}

String _cleanToken(dynamic raw) {
  return (raw ?? '').toString().trim();
}
