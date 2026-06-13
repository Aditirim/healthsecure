import 'package:flutter/material.dart';

enum ComplianceType { hipaa, gdpr, soc2 }

class ComplianceBadge extends StatefulWidget {
  final ComplianceType type;
  final VoidCallback? onTap;

  const ComplianceBadge({
    super.key,
    required this.type,
    this.onTap,
  });

  @override
  State<ComplianceBadge> createState() => _ComplianceBadgeState();
}

class _ComplianceBadgeState extends State<ComplianceBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 3.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.type) {
      case ComplianceType.hipaa:
        return 'HIPAA';
      case ComplianceType.gdpr:
        return 'GDPR';
      case ComplianceType.soc2:
        return 'SOC 2';
    }
  }

  String get _subtitle {
    switch (widget.type) {
      case ComplianceType.hipaa:
        return 'PHISecure';
      case ComplianceType.gdpr:
        return 'Privacy';
      case ComplianceType.soc2:
        return 'Type II';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ComplianceType.hipaa:
        return Icons.health_and_safety;
      case ComplianceType.gdpr:
        return Icons.privacy_tip;
      case ComplianceType.soc2:
        return Icons.verified_user;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);
    final baseGlowColor = primaryColor.withOpacity(0.15);
    final hoverGlowColor = primaryColor.withOpacity(0.35);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            
            final currentScale = _isHovered ? 1.05 : _scaleAnimation.value;
            final currentGlow = _isHovered ? 12.0 : _glowAnimation.value;

            return Transform.scale(
              scale: currentScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withOpacity(_isHovered ? 0.9 : 0.7)
                      : Colors.white.withOpacity(_isHovered ? 0.95 : 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isHovered 
                        ? primaryColor 
                        : primaryColor.withOpacity(0.25),
                    width: _isHovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered ? hoverGlowColor : baseGlowColor,
                      blurRadius: currentGlow,
                      spreadRadius: _isHovered ? 2.0 : 0.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _subtitle,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 10,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
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
    );
  }
}