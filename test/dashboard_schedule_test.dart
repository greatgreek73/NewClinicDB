import 'package:aura_pricing_app/models/appointment.dart';
import 'package:aura_pricing_app/pages/dashboard_page.dart';
import 'package:aura_pricing_app/services/appointment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'dashboard shows real appointments from the appointment service',
    (tester) async {
      final appointmentService = FakeDashboardAppointmentService(
        initialAppointments: [
          Appointment(
            id: 'appointment-1',
            patientId: 'patient-1',
            patientName: 'Ivanov Ivan',
            patientSubtitle: '+7 999 123-45-67 • Moscow',
            startAt: _todayAt(9),
            endAt: _todayAt(10),
            visitLabel: 'Implant consultation',
            roomLabel: AppointmentRoomOption.surgical.label,
            notes: null,
            status: AppointmentStatus.scheduled,
            createdAt: _todayAt(9).subtract(const Duration(days: 1)),
            updatedAt: _todayAt(9).subtract(const Duration(hours: 2)),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClinicDashboardPage(appointmentService: appointmentService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Ivanov Ivan'), findsOneWidget);
      expect(find.text('Implant consultation'), findsOneWidget);
      expect(find.text('Surgical room'), findsOneWidget);
      expect(find.text('Open calendar'), findsOneWidget);
    },
  );
}

class FakeDashboardAppointmentService extends AppointmentService {
  final List<Appointment> _appointments;

  FakeDashboardAppointmentService({
    required List<Appointment> initialAppointments,
  }) : _appointments = List<Appointment>.from(initialAppointments),
       super();

  @override
  Future<List<Appointment>> listByDay(DateTime day) async {
    return appointmentsForLocalDate(_appointments, day);
  }
}

DateTime _todayAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour).toUtc();
}
