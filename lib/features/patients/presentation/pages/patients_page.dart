import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';
import 'package:healthsecure/features/patients/data/models/patient_registration_model.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';
import 'package:healthsecure/features/patients/presentation/pages/patient_registration_page.dart';
import 'package:healthsecure/features/patients/presentation/pages/vitals_recording_page.dart';
import 'dart:math' as math;

class PatientsPage extends StatefulWidget {
  final String? doctorNameFilter;

  const PatientsPage({super.key, this.doctorNameFilter});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  late List<PatientModel> _allPatients;
  late List<PatientModel> _filteredPatients;
  final TextEditingController _searchController = TextEditingController();
  String _userRole = 'Guest';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  Future<void> _loadUserRole() async {
    final role = await CognitoAuthService.instance.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _loadPatients() async {
    try {
      final list = await MockDataService.getPatients(forceRefresh: true);
      if (mounted) {
        setState(() {
          if (widget.doctorNameFilter != null) {
            _allPatients = list.where((p) => p.primaryCarePhysician.toLowerCase() == widget.doctorNameFilter!.toLowerCase()).toList();
          } else {
            _allPatients = list;
          }
          _filteredPatients = _allPatients;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Failed loading patients: $e");
      if (mounted) {
        setState(() {
          _allPatients = [];
          _filteredPatients = [];
          _isLoading = false;
        });
      }
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _allPatients.where((patient) {
        return patient.name.toLowerCase().contains(query) ||
            patient.mrn.toLowerCase().contains(query) ||
            patient.primaryCarePhysician.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getConsentColor(ConsentStatus status) {
    switch (status) {
      case ConsentStatus.signed:
        return AppTheme.complianceSecure;
      case ConsentStatus.pending:
        return AppTheme.complianceWarning;
      case ConsentStatus.expired:
      case ConsentStatus.revoked:
        return AppTheme.complianceDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Registry',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Consent & HIPAA Record Verification',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search patients by name, MRN, or doctor...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.cardTheme.color,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredPatients.length,
              itemBuilder: (context, index) {
                final patient = _filteredPatients[index];
                final consentColor = _getConsentColor(patient.consentStatus);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              patient.getNameForRole(_userRole),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: consentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                patient.consentStatusLabel.toUpperCase(),
                                style: TextStyle(
                                  color: consentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'MRN: ${patient.mrn}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'DOB: ${patient.dateOfBirth}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 0.8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ASSIGNED PHYSICIAN',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  patient.primaryCarePhysician,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'DATA VOLUME',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          patient.isDataEncrypted
                                              ? Icons.lock_outline
                                              : Icons.lock_open_outlined,
                                          size: 14,
                                          color: patient.isDataEncrypted
                                              ? AppTheme.complianceSecure
                                              : AppTheme.complianceDanger,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          patient.isDataEncrypted
                                              ? 'AES-256'
                                              : 'PLAINTEXT',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: patient.isDataEncrypted
                                                ? AppTheme.complianceSecure
                                                : AppTheme.complianceDanger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'INTEGRITY',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${patient.complianceScore.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: patient.complianceScore >= 95.0
                                            ? AppTheme.complianceSecure
                                            : patient.complianceScore >= 75.0
                                                ? AppTheme.complianceWarning
                                                : AppTheme.complianceDanger,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 0.8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => VitalsRecordingPage(
                                      patientName: patient.name,
                                      mrn: patient.mrn,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.favorite_border, size: 16),
                              label: const Text('Record Vitals'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.brightness == Brightness.dark
                                    ? const Color(0xFF2DD4BF)
                                    : const Color(0xFF007E85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToRegistration,
        backgroundColor: theme.brightness == Brightness.dark
            ? const Color(0xFF2DD4BF)
            : const Color(0xFF007E85),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Register Patient',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _navigateToRegistration() async {
    final PatientRegistrationModel? newPatientRegistration = await Navigator.of(context).push<PatientRegistrationModel>(
      MaterialPageRoute(
        builder: (context) => const PatientRegistrationPage(),
      ),
    );

    if (newPatientRegistration != null && mounted) {
      
      final newPatient = PatientModel(
        id: newPatientRegistration.patientId,
        mrn: 'MRN-${newPatientRegistration.patientId.replaceAll('PT-', '')}-${math.Random().nextInt(90) + 10}',
        name: newPatientRegistration.name,
        dateOfBirth: newPatientRegistration.dob,
        consentStatus: ConsentStatus.signed,
        isDataEncrypted: true,
        primaryCarePhysician: 'Dr. Marcus Brody',
        lastAuditDate: DateTime.now(),
        complianceScore: 100.0,
      );

      setState(() {
        _allPatients.insert(0, newPatient);
        _filterPatients();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Chart committed: ${newPatient.name} is now secure.'),
            ],
          ),
          backgroundColor: AppTheme.complianceSecure,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}