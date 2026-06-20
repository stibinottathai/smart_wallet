import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/navigation.dart';
import 'package:smart_wallet/ui/core/theme.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<double> _iconBounce;
  late Animation<double> _taglineFade;
  late Animation<double> _footerFade;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleUp = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _iconBounce = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.55, curve: Curves.elasticOut),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.85, curve: Curves.easeIn),
      ),
    );

    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 3200), _navigateToMain);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationWrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: 500.ms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnim.value * math.pi * 2,
                child: child,
              );
            },
            child: CustomPaint(size: Size.infinite, painter: _SplashPainter()),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.scale(
                    scale: _scaleUp.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _iconBounce,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconBounce.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.0),
                                AppColors.primary.withValues(alpha: 0.08),
                                AppColors.primary.withValues(alpha: 0.0),
                                AppColors.secondary.withValues(alpha: 0.05),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _iconBounce,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconBounce.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.06),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 46,
                            color: AppColors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Smart Wallet',
                    style: GoogleFonts.fraunces(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _taglineFade,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _taglineFade.value,
                        child: child,
                      );
                    },
                    child: Text(
                      'Your Personal Finance Tracker',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text.withValues(alpha: 0.55),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _taglineFade,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (_taglineFade.value * 0.6).clamp(0.0, 1.0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PulsingDot(color: AppColors.primary),
                        const SizedBox(width: 8),
                        _PulsingDot(color: AppColors.primary.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        _PulsingDot(color: AppColors.primary.withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: AnimatedBuilder(
              animation: _footerFade,
              builder: (context, child) {
                return Opacity(
                  opacity: _footerFade.value,
                  child: child,
                );
              },
              child: Text(
                'Offline-First · Private',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.text.withValues(alpha: 0.3),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: 1200.ms,
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.scale(
          scale: _anim.value,
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final primaryPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final secondaryPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX - 80, centerY - 120),
      180,
      primaryPaint,
    );

    canvas.drawCircle(
      Offset(centerX + 100, centerY + 60),
      140,
      secondaryPaint,
    );

    final ringPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(
      Offset(centerX, centerY - 60),
      200,
      ringPaint,
    );

    final ringPaint2 = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(
      Offset(centerX + 40, centerY + 80),
      120,
      ringPaint2,
    );

    final arcPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(center: Offset(centerX - 40, centerY + 40), width: 320, height: 320),
      math.pi * 0.1,
      math.pi * 0.8,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
