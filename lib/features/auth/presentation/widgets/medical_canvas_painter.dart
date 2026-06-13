import 'dart:math' as math;
import 'package:flutter/material.dart';

class MedicalAnimatedIllustration extends StatefulWidget {
  const MedicalAnimatedIllustration({super.key});

  @override
  State<MedicalAnimatedIllustration> createState() => _MedicalAnimatedIllustrationState();
}

class _MedicalAnimatedIllustrationState extends State<MedicalAnimatedIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MedicalCanvasPainter(
            animationValue: _controller.value,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: Container(),
        );
      },
    );
  }
}

class MedicalCanvasPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  MedicalCanvasPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final center = Offset(width / 2, height / 2);

    _drawGrid(canvas, size);

    _drawBioShield(canvas, center, size);

    _drawECGWave(canvas, size);

    _drawOrbitingNodes(canvas, center, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark 
          ? const Color(0xFF0F172A).withOpacity(0.4) 
          : const Color(0xFFE2E8F0).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double gridSpacing = 30.0;
    
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final fineGridPaint = Paint()
      ..color = isDark 
          ? const Color(0xFF0F172A).withOpacity(0.15) 
          : const Color(0xFFE2E8F0).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += gridSpacing / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fineGridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing / 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fineGridPaint);
    }
  }

  void _drawBioShield(Canvas canvas, Offset center, Size size) {
    final double radius = math.min(size.width, size.height) * 0.25;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);
    final accentColor = const Color(0xFF0EA5E9); 

    final outerRingPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final double rotationAngle1 = animationValue * 2 * math.pi;
    _drawDashedArc(canvas, center, radius + 20, 12, rotationAngle1, outerRingPaint);

    final innerRingPaint = Paint()
      ..color = accentColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final double rotationAngle2 = -animationValue * 4 * math.pi;
    _drawDashedArc(canvas, center, radius, 8, rotationAngle2, innerRingPaint);

    final glowPaint = Paint()
      ..color = primaryColor.withOpacity(0.08 + (math.sin(animationValue * 2 * math.pi) * 0.04))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius - 10, glowPaint);

    final shieldPath = Path();
    final double sWidth = radius * 0.5;
    final double sHeight = radius * 0.6;
    final double topY = center.dy - sHeight * 0.5;
    final double bottomY = center.dy + sHeight * 0.6;
    final double leftX = center.dx - sWidth * 0.6;
    final double rightX = center.dx + sWidth * 0.6;
    final double midY = center.dy - sHeight * 0.2;

    shieldPath.moveTo(center.dx, topY);
    
    shieldPath.quadraticBezierTo(
      (center.dx + rightX) / 2, topY - 5,
      rightX, midY,
    );
    
    shieldPath.quadraticBezierTo(
      rightX, (midY + bottomY) / 2,
      center.dx, bottomY,
    );
    
    shieldPath.quadraticBezierTo(
      leftX, (midY + bottomY) / 2,
      leftX, midY,
    );
    
    shieldPath.quadraticBezierTo(
      (center.dx + leftX) / 2, topY - 5,
      center.dx, topY,
    );
    shieldPath.close();

    final shieldPaint = Paint()
      ..color = primaryColor.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, shieldPaint);

    final shieldBorderPaint = Paint()
      ..color = primaryColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(shieldPath, shieldBorderPaint);

    final crossPaint = Paint()
      ..color = accentColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    
    final double crossSize = radius * 0.25;
    final double thickness = crossSize * 0.35;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: crossSize, height: thickness),
        Radius.circular(thickness / 2),
      ),
      crossPaint,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: thickness, height: crossSize),
        Radius.circular(thickness / 2),
      ),
      crossPaint,
    );
  }

  void _drawDashedArc(
    Canvas canvas,
    Offset center,
    double radius,
    int dashCount,
    final double startAngle,
    Paint paint,
  ) {
    final double sweepAngle = (2 * math.pi) / (dashCount * 2);
    for (int i = 0; i < dashCount; i++) {
      final double angle = startAngle + i * (2 * sweepAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  void _drawECGWave(Canvas canvas, Size size) {
    final double baselineY = size.height * 0.8;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);
    
    final wavePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = primaryColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final wavePath = Path();
    bool hasMoved = false;

    final double waveCycle = 260.0;
    final double speed = animationValue * waveCycle;

    for (double x = 0; x < size.width; x += 1.5) {
      
      final double localX = (x + speed) % waveCycle;
      double yOffset = 0.0;

      if (localX > 120 && localX <= 135) {
        
        final double t = (localX - 120) / 15.0;
        yOffset = -8 * math.sin(t * math.pi);
      } else if (localX > 135 && localX <= 140) {
        
        final double t = (localX - 135) / 5.0;
        yOffset = 4 * t;
      } else if (localX > 140 && localX <= 147) {
        
        final double t = (localX - 140) / 7.0;
        if (t < 0.5) {
          yOffset = 4 - (75 * (t / 0.5)); 
        } else {
          yOffset = -71 + (111 * ((t - 0.5) / 0.5)); 
        }
      } else if (localX > 147 && localX <= 152) {
        
        final double t = (localX - 147) / 5.0;
        yOffset = 40 * (1 - t) - 8 * t;
      } else if (localX > 152 && localX <= 165) {
        
        final double t = (localX - 152) / 13.0;
        yOffset = -8 * (1 - t);
      } else if (localX > 165 && localX <= 190) {
        
        final double t = (localX - 165) / 25.0;
        yOffset = -15 * math.sin(t * math.pi);
      }

      final double y = baselineY + yOffset;

      if (!hasMoved) {
        wavePath.moveTo(x, y);
        hasMoved = true;
      } else {
        wavePath.lineTo(x, y);
      }
    }

    canvas.drawPath(wavePath, glowPaint);
    canvas.drawPath(wavePath, wavePaint);

    final double dotX = size.width - ((animationValue * size.width * 2) % size.width);
    final double dotLocalX = (dotX + speed) % waveCycle;
    double dotYOffset = 0.0;
    if (dotLocalX > 120 && dotLocalX <= 135) {
      dotYOffset = -8 * math.sin(((dotLocalX - 120) / 15.0) * math.pi);
    } else if (dotLocalX > 135 && dotLocalX <= 140) {
      dotYOffset = 4 * ((dotLocalX - 135) / 5.0);
    } else if (dotLocalX > 140 && dotLocalX <= 147) {
      final double t = (dotLocalX - 140) / 7.0;
      dotYOffset = t < 0.5 ? 4 - (75 * (t / 0.5)) : -71 + (111 * ((t - 0.5) / 0.5));
    } else if (dotLocalX > 147 && dotLocalX <= 152) {
      dotYOffset = 40 * (1 - (dotLocalX - 147) / 5.0) - 8 * ((dotLocalX - 147) / 5.0);
    } else if (dotLocalX > 152 && dotLocalX <= 165) {
      dotYOffset = -8 * (1 - (dotLocalX - 152) / 13.0);
    } else if (dotLocalX > 165 && dotLocalX <= 190) {
      dotYOffset = -15 * math.sin(((dotLocalX - 165) / 25.0) * math.pi);
    }

    final double dotY = baselineY + dotYOffset;
    final dotPaint = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.fill;
    final dotGlowPaint = Paint()
      ..color = const Color(0xFF0EA5E9).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), 8.0, dotGlowPaint);
    canvas.drawCircle(Offset(dotX, dotY), 4.0, dotPaint);
  }

  void _drawOrbitingNodes(Canvas canvas, Offset center, Size size) {
    final double orbitRadius = math.min(size.width, size.height) * 0.38;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);
    final accentColor = const Color(0xFF0EA5E9);

    final double baseAngle = animationValue * 2 * math.pi;

    final double angle1 = baseAngle;
    final Offset nodePos1 = Offset(
      center.dx + orbitRadius * math.cos(angle1),
      center.dy + orbitRadius * 0.6 * math.sin(angle1), 
    );

    final double angle2 = baseAngle + (2 * math.pi / 3);
    final Offset nodePos2 = Offset(
      center.dx + orbitRadius * math.cos(angle2),
      center.dy + orbitRadius * 0.6 * math.sin(angle2),
    );

    final double angle3 = baseAngle + (4 * math.pi / 3);
    final Offset nodePos3 = Offset(
      center.dx + orbitRadius * math.cos(angle3),
      center.dy + orbitRadius * 0.6 * math.sin(angle3),
    );

    final pathPaint = Paint()
      ..color = primaryColor.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: orbitRadius * 2, height: orbitRadius * 1.2),
      pathPaint,
    );

    final nodePaint = Paint()..style = PaintingStyle.fill;
    final nodeBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    nodePaint.color = primaryColor;
    canvas.drawCircle(nodePos1, 6.0, nodePaint);
    canvas.drawCircle(nodePos1, 6.0, nodeBorder);

    nodePaint.color = accentColor;
    canvas.drawCircle(nodePos2, 5.0, nodePaint);
    canvas.drawCircle(nodePos2, 5.0, nodeBorder);

    nodePaint.color = const Color(0xFF10B981); 
    canvas.drawCircle(nodePos3, 5.5, nodePaint);
    canvas.drawCircle(nodePos3, 5.5, nodeBorder);

    final networkPaint = Paint()
      ..color = primaryColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(nodePos1, nodePos2, networkPaint);
    canvas.drawLine(nodePos2, nodePos3, networkPaint);
    canvas.drawLine(nodePos3, nodePos1, networkPaint);
  }

  @override
  bool shouldRepaint(covariant MedicalCanvasPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isDark != isDark;
  }
}