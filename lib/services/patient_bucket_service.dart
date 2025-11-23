import 'package:cloud_firestore/cloud_firestore.dart';

class PatientBucketEntry {
  final String id;
  final String title;
  final String subtitle;

  PatientBucketEntry({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  factory PatientBucketEntry.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? '').toString().trim();
    final surname = (data['surname'] ?? '').toString().trim();
    final resolvedName = [name, surname].where((v) => v.isNotEmpty).join(' ');

    final phone = (data['phone'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final subtitle = [phone, city].where((v) => v.isNotEmpty).join(' | ');

    return PatientBucketEntry(
      id: doc.id,
      title: resolvedName.isNotEmpty ? resolvedName : 'Patient ${doc.id}',
      subtitle: subtitle.isNotEmpty ? subtitle : 'No contact details',
    );
  }
}

class PatientBucketService {
  static const _patientsCollection = 'patients';
  static const _bucketField = 'priorityBucket';

  Stream<int?> watchPatientBucket(String patientId) {
    return FirebaseFirestore.instance
        .collection(_patientsCollection)
        .doc(patientId)
        .snapshots()
        .map((doc) => _parseBucket(doc.data()));
  }

  Future<void> setPatientBucket(String patientId, int? bucket) async {
    final ref = FirebaseFirestore.instance
        .collection(_patientsCollection)
        .doc(patientId);

    if (bucket == null) {
      await ref.set({_bucketField: FieldValue.delete()}, SetOptions(merge: true));
    } else {
      await ref.set({_bucketField: bucket}, SetOptions(merge: true));
    }
  }

  Stream<List<PatientBucketEntry>> watchPatientsInBucket(int bucket) {
    return FirebaseFirestore.instance
        .collection(_patientsCollection)
        .where(_bucketField, isEqualTo: bucket)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .map(PatientBucketEntry.fromSnapshot)
              .toList();
          entries.sort((a, b) => a.title.compareTo(b.title));
          return entries;
        });
  }

  static int? bucketFromData(Map<String, dynamic>? data) {
    return _parseBucket(data);
  }

  static int? _parseBucket(Map<String, dynamic>? data) {
    final raw = data?[_bucketField];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }
}
