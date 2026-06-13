import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';
import 'package:healthsecure/features/patients/presentation/pages/vitals_recording_page.dart';

class NurseVitalsQueuePage extends StatefulWidget {
  const NurseVitalsQueuePage({super.key});

  @override
  State<NurseVitalsQueuePage> createState() => _NurseVitalsQueuePageState();
}

class _NurseVitalsQueuePageState extends State<NurseVitalsQueuePage> {
  List<PatientModel> _patients = [];
  bool _isLoading = true;
  String _userRole = 'Guest';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadPatients();
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await MockDataService.getPatients(forceRefresh: true);
      if (mounted) {
        setState(() {
          _patients = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _patients = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);

    final totalPatients = _patients.length;
    
    final patientsWithVitals = _patients.where((p) {
      return DemoDataGenerator.instance.vitals.any((v) => v.patientId == p.id);
    }).map((p) => p.id).toSet();

    final completedCount = patientsWithVitals.length;
    final pendingCount = totalPatients - completedCount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nurse Vitals Queue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Vital Telemetry Validation Workflow',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
          ),
        ],
      ),
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildStatCard('TOTAL QUEUE', '$totalPatients', Colors.blue, theme, isDark),
                const SizedBox(width: 12),
                _buildStatCard('COMPLETED', '$completedCount', AppTheme.complianceSecure, theme, isDark),
                const SizedBox(width: 12),
                _buildStatCard('PENDING CHECK', '$pendingCount', AppTheme.complianceWarning, theme, isDark),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : _patients.isEmpty
                    ? const Center(child: Text('No patients in queue.'))
                    : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _patients.length,
                    itemBuilder: (context, index) {
                      final patient = _patients[index];
                      final hasRecordedVitals = patientsWithVitals.contains(patient.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (hasRecordedVitals ? AppTheme.complianceSecure : AppTheme.complianceWarning).withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  hasRecordedVitals ? Icons.favorite : Icons.favorite_border,
                                  color: hasRecordedVitals ? AppTheme.complianceSecure : AppTheme.complianceWarning,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.getNameForRole(_userRole),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          patient.mrn,
                                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12, fontFamily: 'monospace'),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Age: ${patient.age ?? patient.dateOfBirth}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => VitalsRecordingPage(
                                        patientName: patient.name,
                                        mrn: patient.mrn,
                                      ),
                                    ),
                                  );
                                  _loadPatients(); 
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(hasRecordedVitals ? 'Re-record' : 'Record Vitals'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasRecordedVitals ? Colors.transparent : primaryColor,
                                  foregroundColor: hasRecordedVitals ? primaryColor : Colors.white,
                                  elevation: 0,
                                  side: hasRecordedVitals ? BorderSide(color: primaryColor) : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
    );
  }

  Widget _buildStatCard(String label, String value, Color color, ThemeData theme, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}