import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';
import 'package:healthsecure/features/patients/data/models/patient_registration_model.dart';
import 'package:healthsecure/core/services/patient_api_service.dart';

class PipelineMonitoringPage extends StatefulWidget {
  const PipelineMonitoringPage({super.key});

  @override
  State<PipelineMonitoringPage> createState() => _PipelineMonitoringPageState();
}

class _PipelineMonitoringPageState extends State<PipelineMonitoringPage> with SingleTickerProviderStateMixin {
  
  int _validatedCount = 0;
  int _rejectedCount = 0;
  final int _falsePositivesRecovered = 500;
  int _quarantineCount = 0;
  int _pendingCount = 0;
  bool _isLoading = true;

  double get _successRate => (_validatedCount + _rejectedCount) > 0 
      ? (_validatedCount / (_validatedCount + _rejectedCount)) * 100 
      : 0.0;

  final List<LogEntry> _logs = [];
  final ScrollController _terminalScrollController = ScrollController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadPipelineData();
  }

  Future<void> _loadPipelineData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await MockDataService.syncFromBackend();
    } catch (e) {
      print("Failed to sync pipeline telemetry data: $e");
    }

    if (!mounted) return;

    final patients = MockDataService.getPatientsSync();
    final visits = MockDataService.getVisitsSync();
    final vitals = DemoDataGenerator.instance.vitals;
    final audits = MockDataService.getAuditsSync();

    final failedAudits = audits.where((a) => a.status == AuditStatus.failed).length;

    final ingressAudits = audits.where((audit) {
      final nameLower = audit.eventName.toLowerCase();
      final descLower = audit.description.toLowerCase();
      return nameLower.contains('s3') ||
             nameLower.contains('ingress') ||
             nameLower.contains('quarantine') ||
             nameLower.contains('glue') ||
             nameLower.contains('validation') ||
             descLower.contains('s3') ||
             descLower.contains('ingress') ||
             descLower.contains('quarantine') ||
             descLower.contains('glue') ||
             descLower.contains('validation');
    }).toList();

    ingressAudits.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<LogEntry> liveLogs = ingressAudits.map((audit) {
      LogType type = LogType.info;
      if (audit.status == AuditStatus.failed) {
        type = LogType.quarantine;
      } else if (audit.status == AuditStatus.passed &&
                (audit.eventName.toLowerCase().contains('success') ||
                 audit.eventName.toLowerCase().contains('confirmed') ||
                 audit.eventName.toLowerCase().contains('de-identification') ||
                 audit.eventName.toLowerCase().contains('passed') ||
                 audit.eventName.toLowerCase().contains('verify') ||
                 audit.eventName.toLowerCase().contains('valid'))) {
        type = LogType.success;
      }

      return LogEntry(
        timestamp: audit.timestamp,
        type: type,
        message: "${audit.eventName}: ${audit.description}",
      );
    }).toList();

    setState(() {
      _validatedCount = patients.length + visits.length + vitals.length;
      _quarantineCount = failedAudits;
      _rejectedCount = failedAudits;
      _logs.clear();
      _logs.addAll(liveLogs);
      _isLoading = false;
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addLog(String message, LogType type) {
    setState(() {
      _logs.add(LogEntry(
        timestamp: DateTime.now(),
        type: type,
        message: message,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _injectValidRecord() async {
    if (_pendingCount > 0) return;
    
    setState(() {
      _pendingCount = 1;
    });

    _addLog("📥 Ingest Injector: Generating valid patient record...", LogType.info);
    
    try {
      final randomPtId = "PT-${math.Random().nextInt(800) + 200}";
      final newPatient = PatientRegistrationModel(
        patientId: randomPtId,
        name: "Ingress Valid ${math.Random().nextInt(100)}",
        dob: "1995-05-15",
        gender: "Male",
        phone: "+91 98765 43210",
        address: "742 Evergreen Terrace, Springfield",
        bloodGroup: "O+",
        insuranceProvider: "UnitedHealthcare",
        emergencyContact: "Emergency Spouse - +1 555-333-2211",
        weight: 75.0,
        bloodPressure: "120/80",
      );

      _addLog("🚀 Dispatching HTTP POST to AWS API Gateway: /patient", LogType.info);
      await PatientApiService().submitPatientRecord(newPatient);
      
      _addLog("🔑 Ingest confirmed on AWS. Object written to s3://healthsecure-raw-data.", LogType.success);
      _addLog("⚙️ AWS Lambda validation running asynchronously on S3 raw bucket...", LogType.info);
      _addLog("⏳ Synchronizing local logs with S3 in 4 seconds...", LogType.info);

      await Future.delayed(const Duration(seconds: 4));
      await _loadPipelineData();
    } catch (e) {
      _addLog("❌ API Ingress Error: ${e.toString().replaceAll('Exception: ', '')}", LogType.quarantine);
      setState(() {
        _pendingCount = 0;
      });
    }
  }

  Future<void> _injectMalformedRecord() async {
    if (_pendingCount > 0) return;
    
    setState(() {
      _pendingCount = 1;
    });

    _addLog("📥 Ingest Injector: Generating patient record with invalid weight & BP...", LogType.info);
    
    try {
      final randomPtId = "PT-${math.Random().nextInt(800) + 200}";
      final newPatient = PatientRegistrationModel(
        patientId: randomPtId,
        name: "Ingress Malformed ${math.Random().nextInt(100)}",
        dob: "1995-05-15",
        gender: "Female",
        phone: "+91 98765 43210",
        address: "742 Evergreen Terrace, Springfield",
        bloodGroup: "AB-",
        insuranceProvider: "Cigna",
        emergencyContact: "Emergency Spouse - +1 555-333-2211",
        weight: -45.0, 
        bloodPressure: "INVALID-BP", 
      );

      _addLog("🚀 Dispatching HTTP POST to AWS API Gateway: /patient", LogType.info);
      await PatientApiService().submitPatientRecord(newPatient);
      
      _addLog("🔑 Ingest confirmed on AWS. Object written to s3://healthsecure-raw-data.", LogType.success);
      _addLog("⚙️ AWS Lambda validation running asynchronously on S3 raw bucket...", LogType.info);
      _addLog("⚠️ Expecting quarantine rule violations for negative weight & invalid BP.", LogType.info);
      _addLog("⏳ Synchronizing local logs with S3 in 4 seconds...", LogType.info);

      await Future.delayed(const Duration(seconds: 4));
      await _loadPipelineData();
    } catch (e) {
      _addLog("❌ API Ingress Error: ${e.toString().replaceAll('Exception: ', '')}", LogType.quarantine);
      setState(() {
        _pendingCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);
    final size = MediaQuery.of(context).size;

    final isLargeScreen = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), 
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingestion & Validation Pipeline',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'AWS S3 Trigger • Lambda Validator • KMS Encrypt',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _isLoading ? null : _loadPipelineData,
            tooltip: 'Refresh Telemetry',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _isLoading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF10B981),
                        ),
                      )
                    : Container(
                        height: 8,
                        width: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0xFF10B981), blurRadius: 8, spreadRadius: 2),
                          ],
                        ),
                      ),
                const SizedBox(width: 8),
                Text(
                  _isLoading ? 'SYNCING...' : 'TELEMETRY LIVE',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isLargeScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('VALID RECORDS', '$_validatedCount', Icons.check_circle_outline, AppTheme.complianceSecure, isSyncing: _isLoading),
                        _buildStatCard('INVALID RECORDS', '$_rejectedCount', Icons.gpp_bad_outlined, AppTheme.complianceDanger, isSyncing: _isLoading),
                        _buildStatCard('FALSE POSITIVES RECOVERED', '$_falsePositivesRecovered', Icons.history, const Color(0xFF38BDF8), isSyncing: _isLoading),
                        _buildStatCard('QUARANTINE COUNT', '$_quarantineCount', Icons.gpp_maybe_outlined, const Color(0xFFF59E0B), isSyncing: _isLoading),
                        _buildStatCard('VALIDATION SUCCESS RATE', '${_successRate.toStringAsFixed(1)}%', Icons.percent, const Color(0xFF10B981), isSyncing: _isLoading),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildPipelineFlowSection(theme, primaryColor)),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: _buildTerminalSection(theme)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildInjectionToolbar(primaryColor),
                  ],
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: size.width < 600 ? 2 : 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: size.width < 600 ? 1.4 : 1.6,
                        children: [
                          _buildStatCard('VALID RECORDS', '$_validatedCount', Icons.check_circle_outline, AppTheme.complianceSecure, isSyncing: _isLoading),
                          _buildStatCard('INVALID RECORDS', '$_rejectedCount', Icons.gpp_bad_outlined, AppTheme.complianceDanger, isSyncing: _isLoading),
                          _buildStatCard('FALSE POSITIVES RECOVERED', '$_falsePositivesRecovered', Icons.history, const Color(0xFF38BDF8), isSyncing: _isLoading),
                          _buildStatCard('QUARANTINE COUNT', '$_quarantineCount', Icons.gpp_maybe_outlined, const Color(0xFFF59E0B), isSyncing: _isLoading),
                          _buildStatCard('VALIDATION SUCCESS RATE', '${_successRate.toStringAsFixed(1)}%', Icons.percent, const Color(0xFF10B981), isSyncing: _isLoading),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        height: 380,
                        child: _buildPipelineFlowSection(theme, primaryColor),
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        height: 400,
                        child: _buildTerminalSection(theme),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildInjectionToolbar(primaryColor),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool hasPulse = false, bool isSyncing = false}) {
    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(hasPulse ? 0.4 : 0.15), width: 1.2),
        boxShadow: hasPulse ? [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, spreadRadius: 2),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              isSyncing 
                  ? RotationTransition(
                      turns: _pulseController,
                      child: Icon(icon, color: color, size: 16),
                    )
                  : Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );

    if (hasPulse) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: cardContent,
          );
        },
      );
    }
    return cardContent;
  }

  Widget _buildPipelineFlowSection(ThemeData theme, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HIPAA PIPELINE NODE ROUTING',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPipelineNode('s3://healthsecure-raw-data', 'Primary raw ingestion repository', Icons.folder_zip_outlined, Colors.cyan, true),
                  _buildPipelineArrow(),
                  _buildPipelineNode('Lambda: ValidatePatientRecordFunction', 'S3 Put triggered rule validator', Icons.bolt, const Color(0xFFF59E0B), _pendingCount > 0),
                  _buildPipelineArrow(),
                  _buildPipelineNode('KMS AES-256 Encryption', 'HIPAA compliant de-identification & envelope keys', Icons.lock_outline, AppTheme.complianceSecure, false),
                  _buildPipelineArrow(),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPipelineNode('Raw Registry (Success)', 'Valid patient charts committed', Icons.storage, const Color(0xFF10B981), false),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPipelineNode('Quarantine S3 (Rejected)', 'Malformed charts quarantined', Icons.gpp_bad_outlined, AppTheme.complianceDanger, false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineNode(String title, String subtitle, IconData icon, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? color : const Color(0xFF1E293B), width: isActive ? 2.0 : 1.0),
        boxShadow: isActive ? [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
        ] : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 20,
      child: const Center(
        child: Icon(Icons.arrow_downward, color: Color(0xFF334155), size: 16),
      ),
    );
  }

  Widget _buildTerminalSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF020617),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(height: 8, width: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(height: 8, width: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(height: 8, width: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    const Text(
                      'operations-terminal-console',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF64748B), size: 16),
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  tooltip: 'Clear Terminal Output',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF020617),
              child: ListView.builder(
                controller: _terminalScrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final entry = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, height: 1.4),
                        children: [
                          TextSpan(
                            text: "[${entry.formatTime()}] ",
                            style: const TextStyle(color: Color(0xFF334155)),
                          ),
                          TextSpan(
                            text: entry.getTypeTag(),
                            style: TextStyle(color: entry.getTypeColor(), fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: " "),
                          TextSpan(
                            text: entry.message,
                            style: TextStyle(color: entry.getMessageColor()),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInjectionToolbar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CDK INGESTION VALIDATOR PLAYGROUND',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 500;
              final buttons = [
                FilledButton.icon(
                  onPressed: _pendingCount > 0 ? null : _injectValidRecord,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: const Text('Inject Valid Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0ea5e9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pendingCount > 0 ? null : _injectMalformedRecord,
                  icon: const Icon(Icons.gpp_bad_outlined, size: 16),
                  label: const Text('Inject Malformed Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.complianceDanger,
                    side: const BorderSide(color: AppTheme.complianceDanger, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ];

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buttons[0],
                    const SizedBox(height: 12),
                    buttons[1],
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: buttons[0]),
                    const SizedBox(width: 12),
                    Expanded(child: buttons[1]),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

enum LogType { info, success, quarantine }

class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String message;

  LogEntry({required this.timestamp, required this.type, required this.message});

  String formatTime() {
    return "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
  }

  String getTypeTag() {
    switch (type) {
      case LogType.info:
        return "[INFO]";
      case LogType.success:
        return "[VALIDATE-OK]";
      case LogType.quarantine:
        return "[QUARANTINE]";
    }
  }

  Color getTypeColor() {
    switch (type) {
      case LogType.info:
        return const Color(0xFF38BDF8); 
      case LogType.success:
        return const Color(0xFF10B981); 
      case LogType.quarantine:
        return const Color(0xFFEF4444); 
    }
  }

  Color getMessageColor() {
    switch (type) {
      case LogType.info:
        return const Color(0xFFCBD5E1); 
      case LogType.success:
        return const Color(0xFFE2E8F0); 
      case LogType.quarantine:
        return const Color(0xFFFCA5A5); 
    }
  }
}