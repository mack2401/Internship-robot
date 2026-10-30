import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Clean Stitch Card with Soft Shadow and Rounded Corners
class TacticalGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hasGlow;
  final Color glowColor;

  const TacticalGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 20,
    this.hasGlow = false,
    this.glowColor = AppColors.primaryContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.cardBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Stitch Status Pill with round dot indicator
class HudStatusPill extends StatelessWidget {
  final String text;
  final Color dotColor;
  final Color? textColor;
  final IconData? icon;
  final bool isPulsing;

  const HudStatusPill({
    super.key,
    required this.text,
    this.dotColor = AppColors.success,
    this.textColor,
    this.icon,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = dotColor == AppColors.success || dotColor == AppColors.successLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSuccess ? AppColors.successContainer : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSuccess ? AppColors.successBorder : AppColors.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: dotColor),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor ?? (isSuccess ? AppColors.success : AppColors.onSurfaceVariant),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// On-Screen Virtual Touch Joystick
class TacticalJoystick extends StatefulWidget {
  final double size;
  final Function(double x, double y) onDirectionChanged;
  final VoidCallback? onReleased;

  const TacticalJoystick({
    super.key,
    this.size = 140,
    required this.onDirectionChanged,
    this.onReleased,
  });

  @override
  State<TacticalJoystick> createState() => _TacticalJoystickState();
}

class _TacticalJoystickState extends State<TacticalJoystick> {
  Offset _dragPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final maxRadius = (widget.size / 2) - 24;

    return GestureDetector(
      onPanStart: (details) => _updatePosition(details.localPosition, maxRadius),
      onPanUpdate: (details) => _updatePosition(details.localPosition, maxRadius),
      onPanEnd: (_) {
        setState(() {
          _dragPosition = Offset.zero;
        });
        widget.onDirectionChanged(0.0, 0.0);
        widget.onReleased?.call();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.outline, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Directional crosshairs
            Container(
              width: 1,
              height: widget.size * 0.7,
              color: AppColors.outline,
            ),
            Container(
              height: 1,
              width: widget.size * 0.7,
              color: AppColors.outline,
            ),
            // Outer concentric ring
            Container(
              width: widget.size * 0.65,
              height: widget.size * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant),
              ),
            ),
            // Thumb knob
            Transform.translate(
              offset: _dragPosition,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.radio_button_checked,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updatePosition(Offset localPos, double maxRadius) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPos - center;
    final distance = delta.distance;

    Offset clampedDelta = delta;
    if (distance > maxRadius) {
      clampedDelta = Offset.fromDirection(delta.direction, maxRadius);
    }

    setState(() {
      _dragPosition = clampedDelta;
    });

    final normX = clampedDelta.dx / maxRadius;
    final normY = clampedDelta.dy / maxRadius;
    widget.onDirectionChanged(normX, normY);
  }
}

/// Artificial Horizon Inclinometer Instrument
class ArtificialHorizonGauge extends StatelessWidget {
  final double pitch;
  final double roll;
  final double size;

  const ArtificialHorizonGauge({
    super.key,
    required this.pitch,
    required this.roll,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sky & Ground rotating horizon
            Transform.rotate(
              angle: roll * (math.pi / 180),
              child: Transform.translate(
                offset: Offset(0, pitch * 1.5),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: const Color(0xFF38BDF8).withAlpha(160), // Sky
                      ),
                    ),
                    Container(
                      height: 2,
                      color: AppColors.primary,
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF59E0B).withAlpha(160), // Ground
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fixed Aircraft reticle
            CustomPaint(
              size: Size(size, size),
              painter: _ReticlePainter(),
            ),
            // Degree labels
            Positioned(
              top: 6,
              child: Text(
                "P: ${pitch.toStringAsFixed(1)}°",
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              child: Text(
                "R: ${roll.toStringAsFixed(1)}°",
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onSurface
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = AppColors.onSurface);
    canvas.drawLine(Offset(cx - 26, cy), Offset(cx - 8, cy), paint);
    canvas.drawLine(Offset(cx + 8, cy), Offset(cx + 26, cy), paint);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy - 18), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
