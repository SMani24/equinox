import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../data/database/app_database.dart';
import '../../providers/timer_provider.dart';

class TimerDial extends StatefulWidget {
  final TimerState timerState;
  final Activity? preselectedActivity;

  const TimerDial({
    super.key,
    required this.timerState,
    this.preselectedActivity,
  });

  @override
  State<TimerDial> createState() => _TimerDialState();
}

class _TimerDialState extends State<TimerDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.timerState.isRunning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TimerDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timerState.isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.timerState.isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.timerState.isRunning;
    final isPaused = widget.timerState.isPaused;
    final elapsedSeconds = widget.timerState.elapsedSeconds;
    final timeStr = DurationFormatter.formatHms(elapsedSeconds);
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final dialDiameter = isLandscape ? 190.0 : 250.0;

    Color accentColor = AppColors.primaryLight;
    if (widget.preselectedActivity != null) {
      accentColor = Color(widget.preselectedActivity!.colorHex);
    } else if (isPaused) {
      accentColor = AppColors.restMild;
    } else if (isRunning) {
      accentColor = AppColors.primaryLight;
    } else {
      accentColor = AppColors.border;
    }

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = isRunning ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: dialDiameter,
          height: dialDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: isRunning
                  ? accentColor.withValues(alpha: 0.6)
                  : (isPaused
                      ? AppColors.restMild
                      : (widget.preselectedActivity != null
                          ? accentColor.withValues(alpha: 0.5)
                          : AppColors.border)),
              width: 3,
            ),
            boxShadow: [
              if (isRunning)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 36,
                  spreadRadius: 6,
                )
              else if (isPaused)
                BoxShadow(
                  color: AppColors.restMild.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              else if (widget.preselectedActivity != null)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle rotating dash ticks or second indicator
              if (isRunning)
                CustomPaint(
                  size: const Size(250, 250),
                  painter: _DialSecondTickPainter(
                    seconds: elapsedSeconds % 60,
                    accentColor: accentColor,
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isRunning
                          ? accentColor.withValues(alpha: 0.15)
                          : (isPaused
                              ? AppColors.restMild.withValues(alpha: 0.15)
                              : AppColors.surfaceElevated),
                      borderRadius: BorderRadius.circular(12),
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
                                : (isPaused ? AppColors.restMild : AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isRunning
                              ? 'RECORDING'
                              : (isPaused ? 'PAUSED' : 'READY'),
                          style: TextStyle(
                            color: isRunning
                                ? accentColor
                                : (isPaused
                                    ? AppColors.restMild
                                    : AppColors.textMuted),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tabular monospace timer digits
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 44,
                          letterSpacing: -1.0,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.preselectedActivity != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.preselectedActivity!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Text(
                      'START FIRST, CATEGORIZE LATER',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialSecondTickPainter extends CustomPainter {
  final int seconds;
  final Color accentColor;

  _DialSecondTickPainter({required this.seconds, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i += 5) {
      final angle = (i * 6 - 90) * (math.pi / 180);
      final p1 = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final isActive = i <= seconds;
      canvas.drawLine(p1, p2, isActive ? activePaint : paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialSecondTickPainter oldDelegate) {
    return oldDelegate.seconds != seconds ||
        oldDelegate.accentColor != accentColor;
  }
}
