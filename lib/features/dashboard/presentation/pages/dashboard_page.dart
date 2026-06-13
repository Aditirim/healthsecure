import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';
import 'package:healthsecure/features/visits/data/models/visit_model.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/features/dashboard/presentation/pages/pipeline_monitoring_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isLoading = true;

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
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      await MockDataService.syncFromBackend();
    } catch (e) {
      print("Failed to sync dashboard data: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);

    final isDesktop = size.width >= 1100;
    final isTablet = size.width >= 700 && size.width < 1100;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.health_and_safety, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical Console',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Regulatory Standards: HIPAA • SOC 2 Type II • GDPR',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.complianceSecure.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.complianceSecure.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: const [
                Icon(Icons.fiber_manual_record, color: AppTheme.complianceSecure, size: 8),
                SizedBox(width: 6),
                Text(
                  'CDK STACK ONLINE',
                  style: TextStyle(
                    color: AppTheme.complianceSecure,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTotalPatientsCard(theme, primaryColor, isDark)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildTodayVisitsCard(theme, primaryColor, isDark)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildDataQualityCard(theme, primaryColor, isDark)),
                ],
              )
            else if (isTablet)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTotalPatientsCard(theme, primaryColor, isDark)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildTodayVisitsCard(theme, primaryColor, isDark)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDataQualityCard(theme, primaryColor, isDark),
                ],
              )
            else
              Column(
                children: [
                  _buildTotalPatientsCard(theme, primaryColor, isDark),
                  const SizedBox(height: 20),
                  _buildTodayVisitsCard(theme, primaryColor, isDark),
                  const SizedBox(height: 20),
                  _buildDataQualityCard(theme, primaryColor, isDark),
                ],
              ),
            const SizedBox(height: 24),

            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildPipelineCard(theme, primaryColor, isDark)),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: _buildComplianceCard(theme, primaryColor, isDark)),
                ],
              )
            else
              Column(
                children: [
                  _buildPipelineCard(theme, primaryColor, isDark),
                  const SizedBox(height: 20),
                  _buildComplianceCard(theme, primaryColor, isDark),
                ],
              ),
            const SizedBox(height: 24),

            _buildRecentActivitiesCard(theme, primaryColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPatientsCard(ThemeData theme, Color primaryColor, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL PATIENTS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.complianceSecure.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '+12.4%',
                    style: TextStyle(
                      color: AppTheme.complianceSecure,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isLoading ? '...' : '${MockDataService.getPatientsSync().length}',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 36,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Active unique clinical records registered',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              height: 50,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  data: [12, 16, 14, 22, 18, 25, 29],
                  color: primaryColor,
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayVisitsCard(ThemeData theme, Color primaryColor, bool isDark) {
    final visits = MockDataService.getVisitsSync();
    final int total = visits.length;
    final int completed = visits.where((v) => v.syncStatus == EhrSyncStatus.synced).length;
    final int inProgress = visits.where((v) => v.syncStatus == EhrSyncStatus.pending).length;
    final int checkedIn = visits.where((v) => v.syncStatus == EhrSyncStatus.failed).length;
    final double ratio = total > 0 ? completed / total : 1.0;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TODAY'S CONSULTATIONS",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? '...' : '$total',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 36,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled clinical checks today',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(
                  height: 60,
                  width: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 6,
                        backgroundColor: primaryColor.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                      Text(
                        '${(ratio * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                _buildProgressTag(theme, 'Checked-In', '$checkedIn', Colors.orange, isDark),
                const SizedBox(width: 8),
                _buildProgressTag(theme, 'Active', '$inProgress', Colors.blue, isDark),
                const SizedBox(width: 8),
                _buildProgressTag(theme, 'Completed', '$completed', Colors.green, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTag(ThemeData theme, String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
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

  Widget _buildDataQualityCard(ThemeData theme, Color primaryColor, bool isDark) {
    final patients = MockDataService.getPatientsSync();
    
    double completeness = 1.0;
    if (patients.isNotEmpty) {
      int completeCount = 0;
      for (final p in patients) {
        final isComplete = p.mrn.trim().isNotEmpty &&
            (p.phone?.trim().isNotEmpty ?? false) &&
            (p.address?.trim().isNotEmpty ?? false) &&
            (p.insuranceProvider?.trim().isNotEmpty ?? false) &&
            (p.emergencyContact?.trim().isNotEmpty ?? false);
        if (isComplete) completeCount++;
      }
      completeness = completeCount / patients.length;
    }
    
    double validity = 1.0;
    if (patients.isNotEmpty) {
      int validCount = 0;
      final phoneRegex = RegExp(r'^\+?\d[\d\s()+-]{7,20}$');
      for (final p in patients) {
        final phoneVal = p.phone?.trim() ?? '';
        final hasValidPhone = phoneRegex.hasMatch(phoneVal);
        final hasValidMrn = p.mrn.trim().startsWith('MRN');
        if (hasValidPhone && hasValidMrn) validCount++;
      }
      validity = validCount / patients.length;
    }

    double accuracy = 1.0;
    if (patients.isNotEmpty) {
      int accurateCount = patients.where((p) => p.complianceScore >= 90.0).length;
      accuracy = accurateCount / patients.length;
    }

    final double overallScore = ((completeness + validity + accuracy) / 3.0) * 100.0;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "INTEGRITY & DATA QUALITY SCORE",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${overallScore.toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 36,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HIPAA structural validation metrics',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.analytics, color: Colors.cyan, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildQualityBar(theme, 'Completeness', completeness, Colors.cyan),
            const SizedBox(height: 10),
            _buildQualityBar(theme, 'Validity', validity, primaryColor),
            const SizedBox(height: 10),
            _buildQualityBar(theme, 'Accuracy', accuracy, const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityBar(ThemeData theme, String metric, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metric,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              '${(ratio * 100).toInt()}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildPipelineCard(ThemeData theme, Color primaryColor, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CLINICAL DATA INTAKE PIPELINE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PipelineMonitoringPage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.analytics_outlined, color: primaryColor, size: 14),
                  label: Text(
                    'LIVE MONITOR',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: primaryColor.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final bool isCompact = width < 480;

                if (isCompact) {
                  return Column(
                    children: [
                      _buildPipelineStep(theme, 'EHR Ingest', 'Ingesting HL7 CSV/JSON', 'Success', true),
                      _buildPipelineStep(theme, 'HL7 Parse', 'Extracting parameters', 'Success', true),
                      _buildPipelineStep(theme, 'De-Identify', 'Stripping PHI claims', 'Success', true),
                      _buildPipelineStep(theme, 'KMS Encrypt', 'AES-256 Envelope encryption', 'Active', false, isPulsing: true),
                      _buildPipelineStep(theme, 'Audit Ledger', 'Recording transactional logs', 'Pending', false),
                    ],
                  );
                } else {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPipelineStepHorizontal(theme, 'EHR Ingest', 'Ingesting HL7', 'Success', true),
                        _buildPipelineLine(true),
                        _buildPipelineStepHorizontal(theme, 'HL7 Parse', 'Extract params', 'Success', true),
                        _buildPipelineLine(true),
                        _buildPipelineStepHorizontal(theme, 'De-Identify', 'Strip PHI data', 'Success', true),
                        _buildPipelineLine(true),
                        _buildPipelineStepHorizontal(theme, 'KMS Encrypt', 'Envelope crypt', 'Active', false, isPulsing: true),
                        _buildPipelineLine(false),
                        _buildPipelineStepHorizontal(theme, 'Audit Ledger', 'Record trace', 'Pending', false),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStepHorizontal(
    ThemeData theme,
    String stage,
    String sub,
    String status,
    bool isCompleted, {
    bool isPulsing = false,
  }) {
    final Color color = isCompleted
        ? AppTheme.complianceSecure
        : status == 'Active'
            ? const Color(0xFF0EA5E9)
            : const Color(0xFF64748B);

    return SizedBox(
      width: 90,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final double scale = isPulsing ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                    boxShadow: isPulsing
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check
                        : status == 'Active'
                            ? Icons.sync
                            : Icons.lock_clock,
                    color: color,
                    size: 16,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            stage,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineLine(bool isActive) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(top: 18),
      color: isActive ? AppTheme.complianceSecure.withOpacity(0.4) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildPipelineStep(
    ThemeData theme,
    String stage,
    String desc,
    String status,
    bool isCompleted, {
    bool isPulsing = false,
  }) {
    final Color color = isCompleted
        ? AppTheme.complianceSecure
        : status == 'Active'
            ? const Color(0xFF0EA5E9)
            : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isPulsing ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check
                        : status == 'Active'
                            ? Icons.sync
                            : Icons.lock_clock,
                    color: color,
                    size: 14,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCard(ThemeData theme, Color primaryColor, bool isDark) {
    final double overallScore = MockDataService.overallComplianceScore;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REGULATORY COMPLIANCE MONITOR',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.complianceSecure.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.complianceSecure.withOpacity(0.2 * _pulseAnimation.value),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppTheme.complianceSecure,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$overallScore% Compliance Index',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Audit rating across active rules sets',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            (() {
              final audits = MockDataService.getAuditsSync();
              final hipaaAudits = audits.where((a) => a.regulation.toLowerCase().contains('hipaa')).toList();
              final passedHipaa = hipaaAudits.where((a) => a.status == AuditStatus.passed).length;
              final hipaaPct = hipaaAudits.isNotEmpty ? (passedHipaa / hipaaAudits.length) * 100 : 100.0;

              final patients = MockDataService.getPatientsSync();
              final signedConsent = patients.where((p) => p.consentStatus == ConsentStatus.signed).length;
              final gdprPct = patients.isNotEmpty ? (signedConsent / patients.length) * 100 : 100.0;

              final socAudits = audits.where((a) => a.regulation.toLowerCase().contains('soc 2') || a.regulation.toLowerCase().contains('gdpr')).toList();
              final passedSoc = socAudits.where((a) => a.status == AuditStatus.passed).length;
              final socPct = socAudits.isNotEmpty ? (passedSoc / socAudits.length) * 100 : 96.8;

              return Column(
                children: [
                  _buildComplianceRow('HIPAA Rules (Technical)', '${hipaaPct.toStringAsFixed(1)}% Passed', hipaaPct >= 95.0 ? AppTheme.complianceSecure : AppTheme.complianceWarning),
                  const SizedBox(height: 10),
                  _buildComplianceRow('GDPR Rules (Data Privacy)', '${gdprPct.toStringAsFixed(1)}% Passed', gdprPct >= 95.0 ? AppTheme.complianceSecure : AppTheme.complianceWarning),
                  const SizedBox(height: 10),
                  _buildComplianceRow('SOC 2 Audits (Security)', '${socPct.toStringAsFixed(1)}% Passed', socPct >= 95.0 ? AppTheme.complianceSecure : AppTheme.complianceWarning),
                ],
              );
            })(),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.cloud_done, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backup synchronization active (Cloud cold vault)',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitiesCard(ThemeData theme, Color primaryColor, bool isDark) {
    final audits = MockDataService.getAuditsSync().take(5).toList();

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SYSTEM INTEGRITY LOGS & AUDIT TRAIL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Row(
                    children: const [
                      Text('View Regulatory Logs'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: audits.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final audit = audits[index];
                
                final isFailed = audit.status == AuditStatus.failed;
                final isFlagged = audit.status == AuditStatus.flagged;
                
                final statusColor = isFailed
                    ? AppTheme.complianceDanger
                    : isFlagged
                        ? AppTheme.complianceWarning
                        : AppTheme.complianceSecure;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.12),
                        child: Icon(
                          isFailed
                              ? Icons.error_outline
                              : isFlagged
                                  ? Icons.warning_amber_outlined
                                  : Icons.verified_user_outlined,
                          color: statusColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    audit.eventName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
                                  ),
                                  child: Text(
                                    audit.regulation,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              audit.description,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${audit.actorName} (${audit.actorRole})',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.computer, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  audit.ipAddress,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      Text(
                        '${DateTime.now().difference(audit.timestamp).inMinutes}m ago',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
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

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isDark;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    final double maxX = (data.length - 1).toDouble();
    final double minY = data.reduce(math.min);
    final double maxY = data.reduce(math.max);

    final double rangeY = (maxY - minY) == 0 ? 1 : (maxY - minY);

    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final double x = (i / maxX) * width;
      final double y = height - (((data[i] - minY) / rangeY) * height);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.24), color.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    final endPointPaint = Paint()
      ..color = isDark ? const Color(0xFF0EA5E9) : color
      ..style = PaintingStyle.fill;
    
    final endPointGlow = Paint()
      ..color = (isDark ? const Color(0xFF0EA5E9) : color).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.last, 6.0, endPointGlow);
    canvas.drawCircle(points.last, 3.0, endPointPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color || oldDelegate.isDark != isDark;
  }
}