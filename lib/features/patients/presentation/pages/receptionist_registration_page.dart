import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';
import 'package:healthsecure/features/patients/presentation/pages/patient_registration_page.dart';

class ReceptionistRegistrationPage extends StatefulWidget {
  const ReceptionistRegistrationPage({super.key});

  @override
  State<ReceptionistRegistrationPage> createState() => _ReceptionistRegistrationPageState();
}

class _ReceptionistRegistrationPageState extends State<ReceptionistRegistrationPage> {
  late List<PatientModel> _recentPatients;
  bool _isLoading = true;
  String _userRole = 'Guest';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadRecentPatients();
  }

  Future<void> _loadUserRole() async {
    final role = await CognitoAuthService.instance.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _loadRecentPatients() async {
    try {
      final all = await MockDataService.getPatients(forceRefresh: true);
      if (mounted) {
        setState(() {
          _recentPatients = all.take(10).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Failed loading recent patients: $e");
      if (mounted) {
        setState(() {
          _recentPatients = [];
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Intake Center',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Demographics & Insurance Ingestion Desk',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Card(
              elevation: 0,
              color: primaryColor.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: primaryColor.withOpacity(0.15), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final isSmallCard = cardConstraints.maxWidth < 550;
                    
                    final iconContainer = Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_add_alt_1, color: primaryColor, size: 36),
                    );

                    final textColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEW PATIENT INTAKE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start Patient Ingestion',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Launches step-by-step HIPAA and consent validation forms.',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    );

                    final openButton = ElevatedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PatientRegistrationPage(),
                          ),
                        );
                        _loadRecentPatients(); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Open Form', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    );

                    if (isSmallCard) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              iconContainer,
                              const SizedBox(width: 16),
                              Expanded(child: textColumn),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: openButton,
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          iconContainer,
                          const SizedBox(width: 20),
                          Expanded(child: textColumn),
                          const SizedBox(width: 16),
                          openButton,
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              'RECENT REGISTRY LOGS',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentPatients.isEmpty
                    ? const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No recent admissions.'))))
                    : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _recentPatients[index];

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
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.complianceSecure.withOpacity(0.08),
                            child: const Icon(Icons.how_to_reg, color: AppTheme.complianceSecure),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(patient.getNameForRole(_userRole), style: const TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.complianceSecure.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'KMS SECURED',
                                  style: TextStyle(color: AppTheme.complianceSecure, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Row(
                              children: [
                                Text(
                                  patient.mrn,
                                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'monospace', fontSize: 11),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Ins: ${patient.insuranceProvider ?? "None"}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}