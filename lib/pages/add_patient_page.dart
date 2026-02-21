import 'package:flutter/material.dart';

import '../services/id_generator.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';

class AddPatientPage extends StatelessWidget {
  static const routeName = '/add-patient';

  const AddPatientPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PrimaryPageScaffold(child: _AddPatientContent());
  }
}

class _AddPatientContent extends StatefulWidget {
  const _AddPatientContent({Key? key}) : super(key: key);

  @override
  State<_AddPatientContent> createState() => _AddPatientContentState();
}

class _AddPatientContentState extends State<_AddPatientContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  final _photoUrlController = TextEditingController();
  String? _gender;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final photoUrl = _photoUrlController.text.trim();
    if (name.isEmpty || surname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and surname are required.')),
      );
      return;
    }
    final searchKey = _buildSearchKey(surname);

    final age = int.tryParse(_ageController.text.trim());

    final payload = <String, dynamic>{
      'id': generateTextId('patient'),
      'name': name,
      'surname': surname,
      'search_key': searchKey,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    };

    if (phone.isNotEmpty) payload['phone'] = phone;
    if (city.isNotEmpty) payload['city'] = city;
    if (_gender != null && _gender!.isNotEmpty) {
      payload['gender'] = _gender;
    }
    if (age != null) payload['age'] = age;
    if (photoUrl.isNotEmpty) payload['photo_url'] = photoUrl;

    setState(() {
      _isSaving = true;
    });

    try {
      final client = maybeSupabaseClient;
      if (client == null) {
        throw StateError('Supabase is not configured');
      }
      await client.from('patients').insert(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient created.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save patient: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildSearchKey(String surname) {
    return surname.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final leftCard = _buildFormCard(
      title: 'Patient details',
      children: [
        TextFormField(
          controller: _nameController,
          decoration: buildFormInputDecoration('Name'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _surnameController,
          decoration: buildFormInputDecoration('Surname'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: buildFormInputDecoration('Phone'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cityController,
          decoration: buildFormInputDecoration('City'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: buildFormInputDecoration('Gender'),
          dropdownColor: AppColors.surfaceDark,
          value: _gender,
          style: const TextStyle(color: AppColors.textPrimary),
          items: const [
            DropdownMenuItem(value: 'Мужской', child: Text('Мужской')),
            DropdownMenuItem(value: 'Женский', child: Text('Женский')),
          ],
          onChanged: (value) {
            setState(() {
              _gender = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ageController,
          decoration: buildFormInputDecoration('Age'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _photoUrlController,
          decoration: buildFormInputDecoration('Photo URL'),
        ),
      ],
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Add new patient',
            subtitle:
                'Create a profile and assign the first visit to keep the team aligned.',
            actionLabel: 'Back to dashboard',
            onAction: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 28),
          leftCard,
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePatient,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentStrong,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.bg),
                        ),
                      )
                      : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save patient',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
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
