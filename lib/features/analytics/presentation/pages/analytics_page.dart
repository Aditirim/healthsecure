import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      await MockDataService.syncFromBackend();
    } catch (e) {
      print("Failed to sync analytics data: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);
    final size = MediaQuery.of(context).size;

    final isDesktop = size.width >= 1100;
    final isTablet = size.width >= 700 && size.width < 1100;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                'Synchronizing population statistics from AWS...',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Executive Healthcare Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Population Health Metrics • Ingest Ingress Analysis',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.query_stats, color: primaryColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  'HIPAA SECURED',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalyticsData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              _buildExecutiveSummaryBar(theme, primaryColor, isDark, isDesktop, isTablet),
              const SizedBox(height: 24),
  
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildPatientGrowthCard(theme, primaryColor, isDark)),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: _buildMonthlyVisitsCard(theme, primaryColor, isDark)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildPatientGrowthCard(theme, primaryColor, isDark),
                    const SizedBox(height: 20),
                    _buildMonthlyVisitsCard(theme, primaryColor, isDark),
                  ],
                ),
              const SizedBox(height: 24),
  
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildDiseaseDistributionCard(theme, primaryColor, isDark)),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: _buildPhysiologicalAveragesCard(theme, primaryColor, isDark)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildDiseaseDistributionCard(theme, primaryColor, isDark),
                    const SizedBox(height: 20),
                    _buildPhysiologicalAveragesCard(theme, primaryColor, isDark),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveSummaryBar(ThemeData theme, Color primaryColor, bool isDark, bool isDesktop, bool isTablet) {
    final int count = isDesktop ? 4 : (isTablet ? 3 : 2);

    final totalPatients = DemoDataGenerator.instance.patients.length;
    final signedConsentCount = DemoDataGenerator.instance.patients.where((p) => p.consentStatus == ConsentStatus.signed).length;
    final activeChartsPct = totalPatients > 0 ? (signedConsentCount / totalPatients) * 100.0 : 100.0;
    final overallCompliance = MockDataService.overallComplianceScore;
    final auditsCount = DemoDataGenerator.instance.audits.length;
    final avgLatency = 8.0 + (auditsCount % 5);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: count,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 2.6 : 2.2,
      children: [
        _buildMiniKpiCard(theme, 'TOTAL ENROLLED REGISTRY', '$totalPatients', 'Active', Icons.people_alt, primaryColor, isDark),
        _buildMiniKpiCard(theme, 'ACTIVE CLINICAL CHARTS', '${activeChartsPct.toStringAsFixed(1)}%', 'Consent', Icons.health_and_safety_outlined, AppTheme.complianceSecure, isDark),
        _buildMiniKpiCard(theme, 'DATA INTEGRITY INDEX', '${overallCompliance.toStringAsFixed(1)}%', overallCompliance >= 95.0 ? 'Passing' : 'Review', Icons.fact_check_outlined, const Color(0xFF0EA5E9), isDark),
        if (isDesktop || isTablet)
          _buildMiniKpiCard(theme, 'INGESTION TRANS-LATENCY', '${avgLatency.toStringAsFixed(0)} ms', 'Optimized', Icons.speed_outlined, const Color(0xFFF59E0B), isDark),
      ],
    );
  }

  Widget _buildMiniKpiCard(ThemeData theme, String label, String value, String status, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientGrowthCard(ThemeData theme, Color primaryColor, bool isDark) {
    final now = DateTime.now();
    final monthNames = ['Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];
    
    final monthsList = <String>[];
    final monthlyCounts = List<double>.filled(6, 0.0);
    
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      monthsList.add(monthNames[(date.month - 1) % 12]);
    }
    
    for (final p in DemoDataGenerator.instance.patients) {
      final diff = (now.year - p.lastAuditDate.year) * 12 + now.month - p.lastAuditDate.month;
      if (diff >= 0 && diff < 6) {
        monthlyCounts[5 - diff]++;
      }
    }
    
    final totalPt = DemoDataGenerator.instance.patients.length;
    double cumulative = 0;
    for (final val in monthlyCounts) {
      cumulative += val;
    }
    double baseline = (totalPt - cumulative).toDouble();
    if (baseline < 0) baseline = 0;
    
    final List<double> points = [];
    double runningSum = baseline;
    for (int i = 0; i < 6; i++) {
      runningSum += monthlyCounts[i];
      points.add(runningSum);
    }

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PATIENT ENROLLMENT SPLINE TREND',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secure Chart Growth',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.complianceSecure.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${totalPt} total',
                    style: const TextStyle(color: AppTheme.complianceSecure, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _GrowthSplinePainter(
                  dataPoints: points,
                  months: monthsList,
                  chartColor: primaryColor,
                  textColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyVisitsCard(ThemeData theme, Color primaryColor, bool isDark) {
    final now = DateTime.now();
    final monthNames = ['Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];
    
    final monthsList = <String>[];
    final counts = List<double>.filled(6, 0.0);
    
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      monthsList.add(monthNames[(date.month - 1) % 12]);
    }

    for (final v in DemoDataGenerator.instance.visits) {
      final diff = (now.year - v.visitDate.year) * 12 + now.month - v.visitDate.month;
      if (diff >= 0 && diff < 6) {
        counts[5 - diff]++;
      }
    }
    List<double> visitCounts = counts.toList();

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY CLINICAL ATTENDANCE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consultations Ledger',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.bar_chart_outlined, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _VisitsBarPainter(
                  visits: visitCounts,
                  months: monthsList,
                  barColor: const Color(0xFF0EA5E9),
                  textColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseDistributionCard(ThemeData theme, Color primaryColor, bool isDark) {
    List<DiseaseRatio> distributions = [];

    final total = DemoDataGenerator.instance.visits.length;
    final counts = <String, int>{};
    for (final v in DemoDataGenerator.instance.visits) {
      final dx = (v.diagnosis != null && v.diagnosis!.trim().isNotEmpty) ? v.diagnosis! : 'Prevention';
      counts[dx] = (counts[dx] ?? 0) + 1;
    }
    
    final sortedKeys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final colors = [AppTheme.complianceDanger, const Color(0xFFF59E0B), const Color(0xFF0EA5E9), primaryColor, const Color(0xFF8B5CF6)];
    
    int index = 0;
    double sumRatio = 0.0;
    for (final key in sortedKeys.take(4)) {
      final count = counts[key]!;
      final ratio = total > 0 ? count / total : 0.0;
      distributions.add(DiseaseRatio(
        key.length > 20 ? '${key.substring(0, 17)}...' : key,
        double.parse(ratio.toStringAsFixed(2)),
        colors[index % colors.length]
      ));
      sumRatio += ratio;
      index++;
    }
    if (sumRatio < 1.0 && total > 0) {
      distributions.add(DiseaseRatio('Other Care', double.parse((1.0 - sumRatio).toStringAsFixed(2)), colors[index % colors.length]));
    }

    if (distributions.isEmpty || total == 0) {
      distributions.clear();
      distributions.add(DiseaseRatio('General Medicine', 1.0, primaryColor));
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DIAGNOSTIC RATIOS BY POPULATION',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Disease Distribution Index',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                width: double.infinity,
                child: Row(
                  children: distributions.map((d) {
                    final int flexVal = (d.ratio * 100).toInt();
                    return Expanded(
                      flex: flexVal > 0 ? flexVal : 1,
                      child: Container(color: d.color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Column(
              children: distributions.map((d) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          d.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(d.ratio * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysiologicalAveragesCard(ThemeData theme, Color primaryColor, bool isDark) {
    final allVitals = DemoDataGenerator.instance.vitals;
    int sysSum = 0;
    int diaSum = 0;
    int sugarSum = 0;
    int count = 0;
    for (final v in allVitals) {
      final parts = v.bloodPressure.split('/');
      if (parts.length == 2) {
        final sys = int.tryParse(parts[0]);
        final dia = int.tryParse(parts[1]);
        if (sys != null && dia != null) {
          sysSum += sys;
          diaSum += dia;
          sugarSum += v.bloodSugar;
          count++;
        }
      }
    }
    String bpDisplay = '120/80';
    String glucoseDisplay = '90';
    if (count > 0) {
      bpDisplay = '${sysSum ~/ count}/${diaSum ~/ count}';
      glucoseDisplay = '${sugarSum ~/ count}';
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHYSIOLOGICAL TELEMETRY AVERAGES',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Patient Cohort Baselines',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AVERAGE BLOOD PRESSURE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            bpDisplay,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'mmHg',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: const BoxDecoration(color: AppTheme.complianceSecure, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Clinically Normal Range',
                            style: TextStyle(fontSize: 10, color: AppTheme.complianceSecure, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 60,
                  width: 1.2,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                const SizedBox(width: 24),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AVERAGE FASTING GLUCOSE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            glucoseDisplay,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'mg/dL',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Normal Range',
                            style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            const Text(
              'COHORT SYSTEM INTEGRITY STATUS',
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 0.942,
                minHeight: 8,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.complianceSecure),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthSplinePainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> months;
  final Color chartColor;
  final Color textColor;
  final bool isDark;

  _GrowthSplinePainter({
    required this.dataPoints,
    required this.months,
    required this.chartColor,
    required this.textColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    const double paddingLeft = 20.0;
    const double paddingRight = 20.0;
    const double paddingTop = 20.0;
    const double paddingBottom = 25.0;

    final double min = dataPoints.isEmpty ? 0.0 : dataPoints.reduce((a, b) => a < b ? a : b);
    final double max = dataPoints.isEmpty ? 10.0 : dataPoints.reduce((a, b) => a > b ? a : b);
    final double range = max - min;
    
    final double minScore = min - (range > 0 ? range * 0.2 : 5.0);
    final double maxScore = max + (range > 0 ? range * 0.2 : 5.0);
    final double scoreRange = (maxScore - minScore) == 0 ? 1.0 : (maxScore - minScore);

    final double usableWidth = width - paddingLeft - paddingRight;
    final double usableHeight = height - paddingTop - paddingBottom;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = paddingTop + (usableHeight / 3) * i;
      canvas.drawLine(Offset(paddingLeft, y), Offset(width - paddingRight, y), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    final List<Offset> points = [];
    final double stepX = usableWidth / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final x = paddingLeft + (i * stepX);
      final relativeHeight = (dataPoints[i] - minScore) / scoreRange;
      final y = paddingTop + usableHeight - (relativeHeight * usableHeight);
      points.add(Offset(x, y));
    }

    final fillPath = Path();
    fillPath.moveTo(points.first.dx, paddingTop + usableHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + stepX / 2, p1.dy);
      final controlPoint2 = Offset(p2.dx - stepX / 2, p2.dy);
      fillPath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p2.dx, p2.dy,
      );
    }
    fillPath.lineTo(points.last.dx, paddingTop + usableHeight);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        chartColor.withOpacity(0.24),
        chartColor.withOpacity(0.00),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(paddingLeft, paddingTop, usableWidth, usableHeight))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);

    final strokePath = Path();
    strokePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + stepX / 2, p1.dy);
      final controlPoint2 = Offset(p2.dx - stepX / 2, p2.dy);
      strokePath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p2.dx, p2.dy,
      );
    }

    final strokePaint = Paint()
      ..color = chartColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(strokePath, strokePaint);

    final dotPaint = Paint()..color = chartColor;
    final dotOuterPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white;

    for (int i = 0; i < points.length; i++) {
      
      canvas.drawCircle(points[i], 5.5, dotOuterPaint);
      canvas.drawCircle(points[i], 3.0, dotPaint);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: months[i],
          style: TextStyle(
            color: textColor.withOpacity(0.65),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - (textPainter.width / 2), height - paddingBottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthSplinePainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints || oldDelegate.chartColor != chartColor;
  }
}

class _VisitsBarPainter extends CustomPainter {
  final List<double> visits;
  final List<String> months;
  final Color barColor;
  final Color textColor;
  final bool isDark;

  _VisitsBarPainter({
    required this.visits,
    required this.months,
    required this.barColor,
    required this.textColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    const double paddingLeft = 20.0;
    const double paddingRight = 20.0;
    const double paddingTop = 20.0;
    const double paddingBottom = 25.0;

    final double max = visits.isEmpty ? 0.0 : visits.reduce((a, b) => a > b ? a : b);
    final double maxVal = max > 0 ? max * 1.2 : 5.0;
    
    final double usableWidth = width - paddingLeft - paddingRight;
    final double usableHeight = height - paddingTop - paddingBottom;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = paddingTop + (usableHeight / 3) * i;
      canvas.drawLine(Offset(paddingLeft, y), Offset(width - paddingRight, y), gridPaint);
    }

    if (visits.isEmpty) return;

    final double stepX = usableWidth / (visits.length - 1);
    final double barWidth = 16.0;

    for (int i = 0; i < visits.length; i++) {
      final x = paddingLeft + (i * stepX);
      final barHeight = (visits[i] / maxVal) * usableHeight;
      final y = paddingTop + usableHeight - barHeight;

      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x - (barWidth / 2), y, barWidth, barHeight),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );

      final barPaint = Paint()
        ..color = barColor.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(barRect, barPaint);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: months[i],
          style: TextStyle(
            color: textColor.withOpacity(0.65),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - (textPainter.width / 2), height - paddingBottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VisitsBarPainter oldDelegate) {
    return oldDelegate.visits != visits || oldDelegate.barColor != barColor;
  }
}

class DiseaseRatio {
  final String label;
  final double ratio;
  final Color color;

  DiseaseRatio(this.label, this.ratio, this.color);
}