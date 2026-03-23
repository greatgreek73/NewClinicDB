import 'package:aura_pricing_app/services/patient_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patient profile draft builds update payload', () {
    final draft = PatientProfileDraft(
      name: 'Ivan',
      surname: 'Ivanov',
      phone: '12345',
      city: 'Moscow',
      gender: 'Мужской',
      age: 35,
      photoUrl: 'https://example.com/photo.png',
    );

    final payload = draft.toUpdatePayload();

    expect(payload['name'], 'Ivan');
    expect(payload['surname'], 'Ivanov');
    expect(payload['search_key'], 'ivanov');
    expect(payload['phone'], '12345');
    expect(payload['city'], 'Moscow');
    expect(payload['gender'], 'Мужской');
    expect(payload['age'], 35);
    expect(payload['photo_url'], 'https://example.com/photo.png');
    expect(payload['last_updated'], isA<String>());
  });

  test('patient profile draft rejects empty required fields', () {
    expect(
      () => const PatientProfileDraft(name: '', surname: 'Ivanov').validate(),
      throwsStateError,
    );
    expect(
      () => const PatientProfileDraft(name: 'Ivan', surname: '').validate(),
      throwsStateError,
    );
    expect(
      () =>
          const PatientProfileDraft(
            name: 'Ivan',
            surname: 'Ivanov',
            age: 0,
          ).validate(),
      throwsStateError,
    );
  });

  test('patient delete check blocks payments and treatments', () {
    const check = PatientDeleteCheck(
      paymentsCount: 2,
      treatmentsCount: 1,
      appointmentsCount: 3,
      waitingRoomEntriesCount: 3,
    );

    expect(check.hasBlockingDependencies, isTrue);
    expect(check.willRemoveWaitingRoomEntries, isTrue);
    expect(check.blockingReasons, hasLength(3));
  });

  test(
    'patient delete check allows delete when only waiting room entries exist',
    () {
      const check = PatientDeleteCheck(
        paymentsCount: 0,
        treatmentsCount: 0,
        appointmentsCount: 0,
        waitingRoomEntriesCount: 2,
      );

      expect(check.hasBlockingDependencies, isFalse);
      expect(check.willRemoveWaitingRoomEntries, isTrue);
    },
  );
}
