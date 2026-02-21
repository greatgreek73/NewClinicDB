# aura_pricing_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase setup

The app now uses Supabase (instead of Firebase).

Set local credentials once in `lib/supabase_config.local.dart`:

```dart
const localSupabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const localSupabaseAnonKey = 'YOUR_ANON_KEY';
```

Then run normally:

```bash
flutter run
```

You can still override values via `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Expected tables:

- `patients`
- `treatments`

The code reads both naming styles for treatment fields:

- `patientId` or `patient_id`
- `treatmentType` or `treatment_type`
- `toothNumber` or `tooth_number`
