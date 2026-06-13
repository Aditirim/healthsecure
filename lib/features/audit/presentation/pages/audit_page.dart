import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';
import 'package:healthsecure/core/services/mock_data_service.dart';

enum _CategoryFilter {
  all,
  logins,
  ingress,
  visits,
  vitals,
  security,
}

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  late List<AuditModel> _allAudits;
  AuditStatus? _statusFilter;
  _CategoryFilter _categoryFilter = _CategoryFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAuditsData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadAuditsData() async {
    try {
      final list = await MockDataService.getAudits(forceRefresh: true);
      if (mounted) {
        setState(() {
          _allAudits = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Failed loading audits: $e");
      if (mounted) {
        setState(() {
          _allAudits = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Color _getSeverityColor(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.low:
        return const Color(0xFF0EA5E9); 
      case AuditSeverity.medium:
        return const Color(0xFFF59E0B); 
      case AuditSeverity.high:
        return Colors.orange.shade800;
      case AuditSeverity.critical:
        return AppTheme.complianceDanger; 
    }
  }

  Color _getStatusColor(AuditStatus status) {
    switch (status) {
      case AuditStatus.passed:
        return AppTheme.complianceSecure;
      case AuditStatus.flagged:
        return const Color(0xFFF59E0B);
      case AuditStatus.failed:
        return AppTheme.complianceDanger;
    }
  }

  IconData _getStatusIcon(AuditStatus status) {
    switch (status) {
      case AuditStatus.passed:
        return Icons.gpp_good;
      case AuditStatus.flagged:
        return Icons.gpp_maybe;
      case AuditStatus.failed:
        return Icons.gpp_bad;
    }
  }

  String _formatTimestamp(DateTime time) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[time.month - 1]} ${time.day.toString().padLeft(2, '0')}, ${time.year} • ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }

  bool _matchesCategory(AuditModel audit, _CategoryFilter category) {
    final name = audit.eventName.toLowerCase();
    final desc = audit.description.toLowerCase();
    switch (category) {
      case _CategoryFilter.all:
        return true;
      case _CategoryFilter.logins:
        return name.contains('login') || name.contains('auth') || name.contains('cognito');
      case _CategoryFilter.ingress:
        return name.contains('ingress') || name.contains('s3') || name.contains('quarantine');
      case _CategoryFilter.visits:
        return name.contains('ehr') || name.contains('visit') || name.contains('access');
      case _CategoryFilter.vitals:
        return name.contains('vital') || desc.contains('vital') || desc.contains('bp') || desc.contains('heart');
      case _CategoryFilter.security:
        return audit.status == AuditStatus.failed || audit.severity == AuditSeverity.critical || audit.severity == AuditSeverity.high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);

    final filteredAudits = _allAudits.where((audit) {
      final matchesStatus = _statusFilter == null || audit.status == _statusFilter;
      final matchesCategory = _categoryFilter == _CategoryFilter.all || _matchesCategory(audit, _categoryFilter);
      final matchesSearch = audit.eventName.toLowerCase().contains(_searchQuery) ||
          audit.description.toLowerCase().contains(_searchQuery) ||
          audit.actorName.toLowerCase().contains(_searchQuery) ||
          audit.actorRole.toLowerCase().contains(_searchQuery) ||
          audit.regulation.toLowerCase().contains(_searchQuery);
      return matchesStatus && matchesCategory && matchesSearch;
    }).toList();

    final int totalAudits = _allAudits.length;
    final int passedCount = _allAudits.where((a) => a.status == AuditStatus.passed).length;
    final int incidentCount = _allAudits.where((a) => a.status == AuditStatus.failed || a.status == AuditStatus.flagged).length;
    final double compliancePct = totalAudits > 0 ? (passedCount / totalAudits) * 100.0 : 100.0;
    final double incidentPct = totalAudits > 0 ? (incidentCount / totalAudits) * 100.0 : 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Access Audit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'HIPAA Security Rule Active Compliance Monitoring',
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
                Icon(Icons.verified_user_outlined, color: primaryColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  'COMPLIANT LEDGER',
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
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    label: 'TOTAL TRACES',
                    value: '$totalAudits',
                    subLabel: 'Active Ledger',
                    icon: Icons.history_toggle_off_outlined,
                    color: primaryColor,
                    isDark: isDark,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    label: 'VERIFIED SECURE',
                    value: '$passedCount',
                    subLabel: '${compliancePct.toStringAsFixed(1)}% Compliant',
                    icon: Icons.gpp_good_outlined,
                    color: AppTheme.complianceSecure,
                    isDark: isDark,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    label: 'INCIDENTS FLAGGED',
                    value: '$incidentCount',
                    subLabel: '${incidentPct.toStringAsFixed(1)}% Flagged',
                    icon: Icons.gpp_bad_outlined,
                    color: AppTheme.complianceDanger,
                    isDark: isDark,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search audit ledger by Actor, S3 key, Action, or IP...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _CategoryFilter.values.map((cat) {
                final isSelected = _categoryFilter == cat;
                String label;
                IconData icon;
                switch (cat) {
                  case _CategoryFilter.all:
                    label = 'All events';
                    icon = Icons.all_inclusive;
                    break;
                  case _CategoryFilter.logins:
                    label = 'Logins';
                    icon = Icons.vpn_key_outlined;
                    break;
                  case _CategoryFilter.ingress:
                    label = 'S3 Ingestion';
                    icon = Icons.cloud_download_outlined;
                    break;
                  case _CategoryFilter.visits:
                    label = 'EHR Visits';
                    icon = Icons.assignment_outlined;
                    break;
                  case _CategoryFilter.vitals:
                    label = 'Telemetry';
                    icon = Icons.favorite_border;
                    break;
                  case _CategoryFilter.security:
                    label = 'Security Alerts';
                    icon = Icons.security;
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(
                      icon,
                      size: 12,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black54),
                    ),
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: primaryColor,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (selected) {
                      setState(() => _categoryFilter = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Statuses', style: TextStyle(fontSize: 11)),
                  selected: _statusFilter == null,
                  selectedColor: primaryColor,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _statusFilter == null ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    fontWeight: _statusFilter == null ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (selected) {
                    if (selected) setState(() => _statusFilter = null);
                  },
                ),
                ...AuditStatus.values.map((status) {
                  final isSelected = _statusFilter == status;
                  final color = _getStatusColor(status);
                  String label;
                  switch (status) {
                    case AuditStatus.passed:
                      label = 'Secure Green';
                      break;
                    case AuditStatus.flagged:
                      label = 'Warn Orange';
                      break;
                    case AuditStatus.failed:
                      label = 'Critical Red';
                      break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      selectedColor: color.withOpacity(0.15),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (selected) {
                        setState(() => _statusFilter = selected ? status : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAudits.isEmpty
                    ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No clinical audit records located',
                          style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredAudits.length,
                    itemBuilder: (context, index) {
                      final audit = filteredAudits[index];
                      final severityColor = _getSeverityColor(audit.severity);
                      final statusColor = _getStatusColor(audit.status);
                      final statusIcon = _getStatusIcon(audit.status);

                      final isFirst = index == 0;
                      final isLast = index == filteredAudits.length - 1;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            
                            Container(
                              width: 32,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  
                                  CustomPaint(
                                    size: const Size(32, 16),
                                    painter: _DashedLinePainter(
                                      color: isFirst ? Colors.transparent : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                  
                                  Container(
                                    height: 24,
                                    width: 24,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: statusColor, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(statusIcon, color: statusColor, size: 14),
                                    ),
                                  ),
                                  
                                  Expanded(
                                    child: CustomPaint(
                                      size: Size.infinite,
                                      painter: _DashedLinePainter(
                                        color: isLast ? Colors.transparent : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTimestamp(audit.timestamp),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: severityColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              audit.severity.name.toUpperCase(),
                                              style: TextStyle(
                                                color: severityColor,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      Text(
                                        audit.eventName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      Text(
                                        audit.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                      ),
                                      const Divider(height: 24, thickness: 0.8),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    audit.actorRole.toLowerCase().contains('system') || audit.actorRole.toLowerCase().contains('aws')
                                                        ? Icons.cloud_sync_outlined
                                                        : Icons.person_outline,
                                                    size: 12,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'CLINICAL ACTOR',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          letterSpacing: 0.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${audit.actorName} (${audit.actorRole})',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'REGULATION / IP ADDRESS',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  letterSpacing: 0.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${audit.regulation} • ${audit.ipAddress}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String subLabel,
    required IconData icon,
    required Color color,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double dashHeight = 3.0;
    const double dashGap = 4.0;
    
    double startY = 0.0;
    final double endY = size.height;
    final double centerX = size.width / 2;

    while (startY < endY) {
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, math.min(startY + dashHeight, endY)),
        paint,
      );
      startY += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}