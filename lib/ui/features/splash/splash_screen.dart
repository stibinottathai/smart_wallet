import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:smart_wallet/ui/core/navigation.dart';
import 'package:smart_wallet/ui/core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;
  late final Animation<double> _gradientShift;
  late final Animation<double> _float1;
  late final Animation<double> _float2;
  late final Animation<double> _float3;
  late final Animation<double> _float4;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _gradientShift = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.linear),
    );

    _float1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: const _SawTooth(0.0)),
    );
    _float2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: const _SawTooth(0.25)),
    );
    _float3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: const _SawTooth(0.5)),
    );
    _float4 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: const _SawTooth(0.75)),
    );

    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _bgController,
        curve: const _SineWave(periods: 3),
      ),
    );

    _navigateToMain();
  }

  void _navigateToMain() {
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationWrapper(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.08, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Stack(
            children: [
              // Animated gradient background
              _AnimatedGradientBackground(shift: _gradientShift.value),
              // Floating particles
              _FloatingParticles(
                float1: _float1.value,
                float2: _float2.value,
                float3: _float3.value,
                float4: _float4.value,
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing Lottie with glow ring
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow ring
                          Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Native custom wallet animation (better than generic Lottie)
                          const _NativeWalletAnimation(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title with shimmer
                    const _ShimmerTitle(),
                    const SizedBox(height: 12),
                    // Tagline
                    Text(
                      'Your Personal Finance Tracker',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text.withValues(alpha: 0.55),
                        letterSpacing: 0.4,
                      ),
                    ).animate().fadeIn(
                      duration: 800.ms,
                      delay: 600.ms,
                      curve: Curves.easeOut,
                    ).slideY(begin: 12, end: 0, duration: 800.ms, delay: 600.ms, curve: Curves.easeOutCubic),
                  ],
                ),
              ),
              // Footer
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Text(
                  'Offline-First · Private',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text.withValues(alpha: 0.3),
                    letterSpacing: 1.2,
                  ),
                ).animate().fadeIn(
                  duration: 800.ms,
                  delay: 1200.ms,
                  curve: Curves.easeIn,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NativeWalletAnimation extends StatelessWidget {
  const _NativeWalletAnimation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Coin 1 (Gold)
          const Icon(Icons.monetization_on_rounded, size: 36, color: Color(0xFFFFD700))
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(begin: 10, end: -70, duration: 2000.ms, curve: Curves.easeOutCubic)
              .moveX(begin: 0, end: -30, duration: 2000.ms, curve: Curves.easeOut)
              .scaleXY(begin: 0.5, end: 1.2, duration: 2000.ms)
              .fadeOut(delay: 1200.ms, duration: 800.ms),
              
          // Coin 2 (Silver/Lighter Gold)
          const Icon(Icons.monetization_on_rounded, size: 28, color: Color(0xFFFDE047))
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(begin: 15, end: -60, duration: 1800.ms, delay: 600.ms, curve: Curves.easeOutCubic)
              .moveX(begin: 0, end: 35, duration: 1800.ms, delay: 600.ms, curve: Curves.easeOut)
              .scaleXY(begin: 0.4, end: 1.1, duration: 1800.ms, delay: 600.ms)
              .fadeOut(delay: 1500.ms, duration: 900.ms),

          // Coin 3
          const Icon(Icons.monetization_on_rounded, size: 24, color: Color(0xFFFBBF24))
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(begin: 20, end: -50, duration: 1600.ms, delay: 1100.ms, curve: Curves.easeOutCubic)
              .moveX(begin: 0, end: -10, duration: 1600.ms, delay: 1100.ms, curve: Curves.easeOut)
              .scaleXY(begin: 0.3, end: 1.0, duration: 1600.ms, delay: 1100.ms)
              .fadeOut(delay: 1700.ms, duration: 1000.ms),

          // Wallet Base
          Container(
            width: 86,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryLight,
                  AppColors.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Stack(
              children: [
                // Flap
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 35,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(35),
                        bottomRight: Radius.circular(35),
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                // Clasp
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(begin: 0.96, end: 1.04, duration: 1500.ms, curve: Curves.easeInOutSine)
          .shimmer(color: Colors.white.withValues(alpha: 0.3), duration: 2500.ms, delay: 1.seconds),
        ],
      ),
    );
  }
}

class _ShimmerTitle extends StatefulWidget {
  const _ShimmerTitle();

  @override
  State<_ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<_ShimmerTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final shimmerOffset = _shimmerAnim.value;
        final gradient = LinearGradient(
          colors: const [
            Color(0xFF1F2421),
            Color(0xFF1F2421),
            Color(0xFF2F6F5E),
            Color(0xFF1F2421),
            Color(0xFF1F2421),
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          begin: Alignment(-1.0 + shimmerOffset * 2, 0.0),
          end: Alignment(1.0 + shimmerOffset * 2, 0.0),
        );
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => gradient.createShader(bounds),
          child: Text(
            'Smart Wallet',
            style: GoogleFonts.fraunces(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ).animate().fadeIn(
            duration: 800.ms,
            delay: 200.ms,
            curve: Curves.easeOut,
          ).slideY(begin: 20, end: 0, duration: 800.ms, delay: 200.ms, curve: Curves.easeOutCubic),
        );
      },
    );
  }
}

class _AnimatedGradientBackground extends StatelessWidget {
  final double shift;
  const _AnimatedGradientBackground({required this.shift});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GradientPainter(shift: shift),
    );
  }
}

class _GradientPainter extends CustomPainter {
  final double shift;
  _GradientPainter({required this.shift});

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = RadialGradient(
      center: Alignment(0.3 - shift * 0.3, -0.2 + shift * 0.2),
      radius: 1.2,
      colors: [
        AppColors.primaryLight.withValues(alpha: 0.35 - shift * 0.1),
        AppColors.primary.withValues(alpha: 0.08 - shift * 0.03),
        Colors.transparent,
      ],
    );

    final rect = Offset.zero & size;
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    final gradient2 = RadialGradient(
      center: Alignment(-0.4 + shift * 0.4, 0.5 - shift * 0.3),
      radius: 1.0,
      colors: [
        AppColors.secondaryLight.withValues(alpha: 0.2 - shift * 0.05),
        Colors.transparent,
        Colors.transparent,
      ],
    );

    final paint2 = Paint()..shader = gradient2.createShader(rect);
    canvas.drawRect(rect, paint2);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter old) => old.shift != shift;
}

class _FloatingParticles extends StatelessWidget {
  final double float1;
  final double float2;
  final double float3;
  final double float4;

  const _FloatingParticles({
    required this.float1,
    required this.float2,
    required this.float3,
    required this.float4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ParticlePainter(
        float1: float1,
        float2: float2,
        float3: float3,
        float4: float4,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double float1;
  final double float2;
  final double float3;
  final double float4;

  _ParticlePainter({
    required this.float1,
    required this.float2,
    required this.float3,
    required this.float4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particles = [
      _ParticleData(0.15 * size.width, 0.7 + float1 * 0.3, 6, AppColors.primary.withValues(alpha: 0.12 - float1 * 0.04)),
      _ParticleData(0.85 * size.width, 0.6 - float2 * 0.25, 4, AppColors.secondary.withValues(alpha: 0.1 - float2 * 0.03)),
      _ParticleData(0.25 * size.width, 0.3 - float3 * 0.2, 8, AppColors.primaryLight.withValues(alpha: 0.15 - float3 * 0.05)),
      _ParticleData(0.7 * size.width, 0.8 + float4 * 0.2, 5, AppColors.primary.withValues(alpha: 0.08 - float4 * 0.03)),
      _ParticleData(0.5 * size.width, 0.4 + float1 * 0.15, 3, AppColors.secondary.withValues(alpha: 0.07 - float1 * 0.02)),
      _ParticleData(0.1 * size.width, 0.5 - float3 * 0.15, 7, AppColors.primaryLight.withValues(alpha: 0.1 - float3 * 0.03)),
      _ParticleData(0.9 * size.width, 0.3 - float2 * 0.2, 5, AppColors.primary.withValues(alpha: 0.09 - float2 * 0.03)),
    ];

    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x, p.y * size.height),
        p.radius,
        Paint()..color = p.color,
      );

      if (p.radius > 5) {
        canvas.drawCircle(
          Offset(p.x, p.y * size.height),
          p.radius * 1.8,
          Paint()
            ..color = p.color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
    old.float1 != float1 || old.float2 != float2 || old.float3 != float3 || old.float4 != float4;
}

class _ParticleData {
  final double x;
  final double y;
  final double radius;
  final Color color;
  const _ParticleData(this.x, this.y, this.radius, this.color);
}

class _SineWave extends Curve {
  final int periods;
  const _SineWave({this.periods = 1});

  @override
  double transformInternal(double t) {
    return (math.sin(t * 2 * math.pi * periods) + 1) / 2;
  }
}

class _SawTooth extends Curve {
  final double phaseOffset;
  const _SawTooth(this.phaseOffset);

  @override
  double transformInternal(double t) {
    return ((t + phaseOffset) % 1.0).toDouble();
  }
}
