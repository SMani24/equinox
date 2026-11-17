import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../data/database/app_database.dart';
import '../../providers/timer_provider.dart';

/// Calm progressive timer ring.
/// Fills 1 full turn every 60 minutes, stacking subtle concentric inner rings
/// for multi-hour sessions. Subtle opacity breathing glow replaces wobbly scaling.
class TimerDial extends StatefulWidget {
  final TimerState timerState;
  final Activity? preselectedActivity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TimerDial({
    super.key,
    required this.timerState,
    this.preselectedActivity,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<TimerDial> createState() => _TimerDialState();
}

class _TimerDialState extends State<TimerDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _glowOpacity = Tween<double>(begin: 0.10, end: 0.26).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.timerState.isRunning) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TimerDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timerState.isRunning && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.timerState.isRunning && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final isRunning = widget.timerState.isRunning;
    final isPaused = widget.timerState.isPaused;
    final elapsedSeconds = widget.timerState.elapsedSeconds;
    final timeStr = DurationFormatter.formatHms(elapsedSeconds);
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final dialDiameter = isLandscape ? 186.0 : 238.0;

    final Color accentColor;
    if (widget.preselectedActivity != null) {
      accentColor = Color(widget.preselectedActivity!.colorHex);
    } else if (isPaused) {
      accentColor = eq.spend;
    } else {
      accentColor = eq.accent;
    }

    final double lapProgress = (elapsedSeconds % 3600) / 3600.0;
    final int completedLaps = elapsedSeconds ~/ 3600;

    return Center(
      child: Semantics(
        button: widget.onTap != null,
        label: isRunning
            ? 'Timer running $timeStr. Tap to pause, hold to stop and log.'
            : (isPaused
                ? 'Timer paused at $timeStr. Tap to resume, hold to stop and log.'
                : 'Timer ready. Tap to start.'),
        child: GestureDetector(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  widget.onLongPress!();
                },
          child: AnimatedBuilder(
            animation: _glowOpacity,
            builder: (context, child) {
              final glowAlpha = isRunning
                  ? _glowOpacity.value
                  : (isPaused ? 0.10 : (widget.preselectedActivity != null ? 0.10 : 0.0));
              return Container(
                width: dialDiameter,
                height: dialDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: eq.surface1,
                  boxShadow: glowAlpha > 0
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: glowAlpha),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(dialDiameter, dialDiameter),
                  painter: _ProgressiveRingPainter(
                    progress: isRunning || isPaused ? lapProgress : 0.0,
                    completedLaps: isRunning || isPaused ? completedLaps : 0,
                    isPaused: isPaused,
                    isIdle: !isRunning && !isPaused,
                    accentColor: accentColor,
                    trackColor: eq.surface3,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status pill
                      AnimatedContainer(
                        duration: Motion.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isRunning
                              ? accentColor.withValues(alpha: 0.14)
                              : (isPaused ? eq.spendSoft : eq.surface2),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRunning
                                    ? accentColor
                                    : (isPaused ? eq.spend : eq.textMuted),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isRunning
                                  ? 'Recording'
                                  : (isPaused ? 'Paused' : 'Ready'),
                              style: TextStyle(
                                color: isRunning
                                    ? accentColor
                                    : (isPaused ? eq.spend : eq.textSecondary),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isLandscape ? 6 : 10),
                      // Light tabular timer digits
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          timeStr,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: isLandscape ? 36 : 44,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -1.0,
                                color: isPaused
                                    ? eq.textPrimary.withValues(alpha: 0.7)
                                    : eq.textPrimary,
                              ),
                        ),
                      ),
                      SizedBox(height: isLandscape ? 4 : 8),
                      if (widget.preselectedActivity != null)
                        Text(
                          widget.preselectedActivity!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          isRunning
                              ? 'Hold to stop & log'
                              : (isPaused ? 'Tap to resume' : 'Tap ring or pick below'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: eq.textMuted,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressiveRingPainter extends CustomPainter {
  final double progress;
  final int completedLaps;
  final bool isPaused;
  final bool isIdle;
  final Color accentColor;
  final Color trackColor;

  _ProgressiveRingPainter({
    required this.progress,
    required this.completedLaps,
    required this.isPaused,
    required this.isIdle,
    required this.accentColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 6.0;
    final outerRadius = (math.min(size.width, size.height) - strokeWidth * 2) / 2;

    // Base track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isIdle ? 2.5 : strokeWidth;
    canvas.drawCircle(center, outerRadius, trackPaint);

    if (isIdle) return;

    final effectiveColor =
        isPaused ? accentColor.withValues(alpha: 0.45) : accentColor;

    // Draw completed hour laps as subtle inner concentric rings (up to 3)
    final lapsToShow = math.min(completedLaps, 3);
    for (int lap = 0; lap < lapsToShow; lap++) {
      final innerR = outerRadius - (lap + 1) * 7.5;
      if (innerR <= 16) break;
      final innerPaint = Paint()
        ..color = effectiveColor.withValues(alpha: 0.30 - lap * 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, innerR, innerPaint);
    }

    // Current hour arc (minimum sliver so active state reads clearly)
    final sweep = math.max(0.02, progress) * 2 * math.pi;
    final arcPaint = Paint()
      ..color = effectiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressiveRingPainter old) {
    return old.progress != progress ||
        old.completedLaps != completedLaps ||
        old.isPaused != isPaused ||
        old.isIdle != isIdle ||
        old.accentColor != accentColor ||
        old.trackColor != trackColor;
  }
}
