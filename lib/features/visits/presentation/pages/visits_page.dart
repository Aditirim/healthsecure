import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/visits/data/models/visit_model.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';
import 'package:healthsecure/features/visits/data/repositories/visit_repository.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';

class VisitsPage extends StatefulWidget {
  final String? providerNameFilter;

  const VisitsPage({super.key, this.providerNameFilter});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  late List<VisitModel> _allVisits;
  late List<VisitModel> _filteredVisits;
  late List<PatientModel> _allPatients;
  String _userRole = 'Guest';

  bool _showTimelineView = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadVisitsData();
    _searchController.addListener(_filterVisits);
  }

  Future<void> _loadUserRole() async {
    final role = await CognitoAuthService.instance.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _loadVisitsData() async {
    try {
      final visitsList = await MockDataService.getVisits(forceRefresh: true);
      final patientsList = await MockDataService.getPatients();
      if (mounted) {
        setState(() {
          if (widget.providerNameFilter != null) {
            _allVisits = visitsList.where((v) => v.providerName.toLowerCase() == widget.providerNameFilter!.toLowerCase()).toList();
          } else {
            _allVisits = visitsList;
          }
          _filteredVisits = _allVisits;
          _allPatients = patientsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Failed loading visits: $e");
      if (mounted) {
        setState(() {
          _allVisits = [];
          _filteredVisits = [];
          _allPatients = [];
          _isLoading = false;
        });
      }
    }
  }

  void _filterVisits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVisits = _allVisits.where((visit) {
        return visit.patientName.toLowerCase().contains(query) ||
            visit.mrn.toLowerCase().contains(query) ||
            visit.providerName.toLowerCase().contains(query) ||
            visit.notes.toLowerCase().contains(query) ||
            visit.id.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getSyncColor(EhrSyncStatus status) {
    switch (status) {
      case EhrSyncStatus.synced:
        return AppTheme.complianceSecure;
      case EhrSyncStatus.pending:
        return AppTheme.complianceWarning;
      case EhrSyncStatus.failed:
        return AppTheme.complianceDanger;
    }
  }

  IconData _getSyncIcon(EhrSyncStatus status) {
    switch (status) {
      case EhrSyncStatus.synced:
        return Icons.cloud_done_outlined;
      case EhrSyncStatus.pending:
        return Icons.cloud_sync_outlined;
      case EhrSyncStatus.failed:
        return Icons.cloud_off_outlined;
    }
  }

  void _showAddVisitSheet(BuildContext context, Color primaryColor, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final randomId = 'VS-${math.Random().nextInt(900) + 100}';
    
    PatientModel? selectedPatient;
    String selectedDoctor = 'Dr. Marcus Brody';
    final complaintController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final doctors = ['Dr. Marcus Brody', 'Dr. Sarah Chen', 'Dr. Elena Rostova'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.note_add_outlined, color: primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Log Clinical Consultation',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        initialValue: randomId,
                        enabled: false,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Intake Visit ID',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          suffixIcon: const Icon(Icons.lock, size: 16),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      DropdownButtonFormField<PatientModel>(
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Select Patient (From Registry)',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: _allPatients.map((PatientModel patient) {
                          return DropdownMenuItem<PatientModel>(
                            value: patient,
                            child: Text('${patient.getNameForRole(_userRole)} (${patient.mrn})'),
                          );
                        }).toList(),
                        validator: (value) {
                          if (value == null) return 'Please bind a registered patient';
                          return null;
                        },
                        onChanged: (PatientModel? newVal) {
                          selectedPatient = newVal;
                        },
                      ),
                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        value: selectedDoctor,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Attending Practitioner',
                          prefixIcon: const Icon(Icons.medical_services_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: doctors.map((String doc) {
                          return DropdownMenuItem<String>(
                            value: doc,
                            child: Text(doc),
                          );
                        }).toList(),
                        onChanged: (String? newVal) {
                          if (newVal != null) {
                            selectedDoctor = newVal;
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(primary: primaryColor),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, color: primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                "Consultation Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: complaintController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Chief Complaint & Clinical Notes',
                          hintText: 'Describe patient primary symptoms and diagnosis plan...',
                          prefixIcon: const Icon(Icons.history_edu_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Chief complaint documentation is required';
                          }
                          if (value.trim().length < 5) {
                            return 'Enter detailed clinical findings';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      FilledButton(
                        onPressed: () {
                          if (formKey.currentState!.validate() && selectedPatient != null) {
                            final newVisit = VisitModel(
                              id: randomId,
                              patientId: selectedPatient!.id,
                              patientName: selectedPatient!.name,
                              mrn: selectedPatient!.mrn,
                              providerName: selectedDoctor,
                              visitDate: selectedDate,
                              syncStatus: EhrSyncStatus.synced, 
                              hasPhysicianSignature: true, 
                              billingCoded: true,
                              complianceCleared: true,
                              notes: complaintController.text.trim(),
                            );

                            VisitRepository().saveVisit(newVisit).then((_) {
                              print("Successfully saved visit to live AWS S3.");
                            }).catchError((err) {
                              print("Failed saving visit to live AWS S3: $err");
                            });

                            setState(() {
                              
                              _allVisits.insert(0, newVisit);
                              _filterVisits();
                            });

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Text('EHR visit log committed: ${newVisit.id} is secure.'),
                                  ],
                                ),
                                backgroundColor: AppTheme.complianceSecure,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Commit Consultation Record',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
              'Clinical Consultations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'EHR Sync & Credential Signature Checklist',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          
          IconButton(
            icon: Icon(_showTimelineView ? Icons.dashboard_outlined : Icons.format_list_bulleted),
            tooltip: _showTimelineView ? 'Grid Cards View' : 'Chronological Timeline',
            onPressed: () {
              setState(() {
                _showTimelineView = !_showTimelineView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
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
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search consultations by patient, MRN, doctor or diagnosis...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.cardTheme.color,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisits.isEmpty
                    ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(
                          'No consultations found matching your filter.',
                          style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : _showTimelineView
                    ? _buildTimelineView(theme, isDark)
                    : _buildGridCardsView(theme, isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVisitSheet(context, primaryColor, isDark),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add),
        label: const Text(
          'Log Consultation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildGridCardsView(ThemeData theme, bool isDark) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredVisits.length,
      itemBuilder: (context, index) {
        final visit = _filteredVisits[index];
        final syncColor = _getSyncColor(visit.syncStatus);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        visit.id,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${visit.visitDate.month}/${visit.visitDate.day}/${visit.visitDate.year} at ${visit.visitDate.hour.toString().padLeft(2, '0')}:${visit.visitDate.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Text(
                  visit.getPatientNameForRole(_userRole),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MRN: ${visit.mrn} • Practitioner: ${visit.providerName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    visit.notes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                ),
                const Divider(height: 24, thickness: 0.8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    
                    _buildChecklistStatus(
                      context,
                      label: 'EHR SYNC',
                      value: visit.syncStatus.name.toUpperCase(),
                      icon: _getSyncIcon(visit.syncStatus),
                      color: syncColor,
                    ),
                    
                    _buildChecklistStatus(
                      context,
                      label: 'SIGNATURE',
                      value: visit.hasPhysicianSignature ? 'CAPTURED' : 'MISSING',
                      icon: visit.hasPhysicianSignature
                          ? Icons.assignment_turned_in_outlined
                          : Icons.assignment_late_outlined,
                      color: visit.hasPhysicianSignature
                          ? AppTheme.complianceSecure
                          : AppTheme.complianceDanger,
                    ),

                    _buildChecklistStatus(
                      context,
                      label: 'CODING',
                      value: visit.billingCoded ? 'VALIDATED' : 'PENDING',
                      icon: visit.billingCoded
                          ? Icons.monetization_on_outlined
                          : Icons.hourglass_empty_outlined,
                      color: visit.billingCoded
                          ? AppTheme.complianceSecure
                          : AppTheme.complianceWarning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChecklistStatus(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineView(ThemeData theme, bool isDark) {
    
    final sortedVisits = List<VisitModel>.from(_filteredVisits)
      ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: sortedVisits.length,
      itemBuilder: (context, index) {
        final visit = sortedVisits[index];
        final syncColor = _getSyncColor(visit.syncStatus);
        
        final bool isLast = index == sortedVisits.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            SizedBox(
              width: 55,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${visit.visitDate.month}/${visit.visitDate.day}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${visit.visitDate.year}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            Column(
              children: [
                Container(
                  height: 18,
                  width: 18,
                  decoration: BoxDecoration(
                    color: syncColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: syncColor, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      height: 6,
                      width: 6,
                      decoration: BoxDecoration(
                        color: syncColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    height: 120, 
                    width: 2,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          visit.providerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: syncColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            visit.id,
                            style: TextStyle(
                              color: syncColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${visit.getPatientNameForRole(_userRole)} (${visit.mrn})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      visit.notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          visit.hasPhysicianSignature ? Icons.assignment_turned_in : Icons.assignment_late,
                          size: 12,
                          color: visit.hasPhysicianSignature ? AppTheme.complianceSecure : AppTheme.complianceDanger,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          visit.hasPhysicianSignature ? 'Signed Chart' : 'Unsigned Chart',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: visit.hasPhysicianSignature ? AppTheme.complianceSecure : AppTheme.complianceDanger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}