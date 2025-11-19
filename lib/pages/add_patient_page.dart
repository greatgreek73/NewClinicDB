import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';

class AddPatientPage extends StatelessWidget {
  static const routeName = '/add-patient';

  const AddPatientPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      maxWidth: 960,
      child: const _AddPatientContent(),
    );
  }
}

class _AddPatientContent extends StatelessWidget {
  const _AddPatientContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        final leftCard = _buildFormCard(
          title: 'Patient details',
          children: [
            TextField(decoration: buildFormInputDecoration('Full name')),
            const SizedBox(height: 16),
            TextField(
              decoration:
                  buildFormInputDecoration('Date of birth', hint: 'DD/MM/YYYY'),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: buildFormInputDecoration('Preferred doctor'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: buildFormInputDecoration('Primary concern'),
              dropdownColor: AppColors.surfaceDark,
              style: const TextStyle(color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: 'Implant', child: Text('Implants')),
                DropdownMenuItem(value: 'Hygiene', child: Text('Hygiene')),
                DropdownMenuItem(value: 'Whitening', child: Text('Whitening')),
              ],
              onChanged: (_) {},
            ),
          ],
        );

        final rightCard = _buildFormCard(
          title: 'Contact & notes',
          children: [
            TextField(decoration: buildFormInputDecoration('Phone number')),
            const SizedBox(height: 16),
            TextField(decoration: buildFormInputDecoration('Email')),
            const SizedBox(height: 16),
            TextField(
              maxLines: 4,
              decoration: buildFormInputDecoration(
                'Notes for care team',
                hint: 'Allergies, previous procedures, reminders...',
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Add new patient',
              subtitle: 'Create a profile and assign the first visit to keep the team aligned.',
              actionLabel: 'Back to dashboard',
              onAction: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 28),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftCard),
                  const SizedBox(width: 24),
                  Expanded(child: rightCard),
                ],
              )
            else ...[
              leftCard,
              const SizedBox(height: 24),
              rightCard,
            ],
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentStrong,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save patient',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
