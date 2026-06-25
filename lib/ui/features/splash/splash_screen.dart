import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/lock/views/app_lock_gate.dart';

/// Total time the splash is on screen before navigating away.
const _kSplashDuration = Duration(milliseconds: 3200);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Ambient loop: gradient drift, particles, ripple rings.
  late final AnimationController _ambient;
  // One-shot intro that fills the progress bar and tracks elapsed time.
  late final AnimationController _intro;

  late final Animation<double> _gradientShift;
  late final Animation<double> _float1;
  late final Animation<double> _float2;
  late final Animation<double> _float3;
  late final Animation<double> _float4;
  late final Animation<double> _ripple;

  @override
  void initState() {
    super.initState();

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: _kSplashDuration,
    )..forward();

    _gradientShift = CurvedAnimation(parent: _ambient, curve: Curves.linear);

    _float1 = CurvedAnimation(parent: _ambient, curve: const _SawTooth(0.0));
    _float2 = CurvedAnimation(parent: _ambient, curve: const _SawTooth(0.25));
    _float3 = CurvedAnimation(parent: _ambient, curve: const _SawTooth(0.5));
    _float4 = CurvedAnimation(parent: _ambient, curve: const _SawTooth(0.75));

    _ripple = CurvedAnimation(parent: _ambient, curve: Curves.linear);

    _navigateToMain();
  }

  void _navigateToMain() {
    Future.delayed(_kSplashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AppLockGate(),
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
    _ambient.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          return Stack(
            children: [
              // Drifting radial gradient wash.
              _AnimatedGradientBackground(shift: _gradientShift.value),
              // Floating ambient particles.
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
                    // Logo: expanding ripple rings behind a wallet that
                    // catches falling coins.
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _RippleRings(progress: _ripple.value),
                          const _NativeWalletAnimation(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title with shimmer sweep.
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
                    )
                        .animate()
                        .fadeIn(
                          duration: 800.ms,
                          delay: 700.ms,
                          curve: Curves.easeOut,
                        )
                        .slideY(
                          begin: 0.8,
                          end: 0,
                          duration: 800.ms,
                          delay: 700.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
              // Slim progress bar synced to the splash duration.
              Positioned(
                left: 0,
                right: 0,
                bottom: 72,
                child: Center(
                  child: _LoadingBar(controller: _intro)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 900.ms),
                ),
              ),
              // Footer
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
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
                      delay: 1300.ms,
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

/// Three concentric rings that expand and fade outward, looping. Gives the
/// logo a sense of energy radiating from the wallet.
class _RippleRings extends StatelessWidget {
  final double progress;
  const _RippleRings({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: _RipplePainter(progress: progress),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  _RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const minRadius = 60.0;
    final maxRadius = size.width / 2;

    // Three rings staggered by 1/3 of the cycle.
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = minRadius + (maxRadius - minRadius) * t;
      // Fade out as the ring grows.
      final alpha = (1.0 - t) * 0.22;
      if (alpha <= 0) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppColors.primary.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Soft static halo right behind the wallet.
    canvas.drawCircle(
      center,
      minRadius,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.progress != progress;
}

class _NativeWalletAnimation extends StatelessWidget {
  const _NativeWalletAnimation();

  // A single coin that drops from above, lands at the wallet slot with a
  // little bounce, then sinks in (shrinks + fades). [delay] staggers them.
  Widget _coin({
    required double size,
    required Color color,
    required double dx,
    required Duration delay,
  }) {
    return Icon(Icons.monetization_on_rounded, size: size, color: color)
        .animate(onPlay: (c) => c.repeat())
        // gravity fall onto the wallet
        .moveY(
          begin: -90,
          end: -8,
          duration: 900.ms,
          delay: delay,
          curve: Curves.bounceOut,
        )
        .moveX(begin: dx, end: dx * 0.3, duration: 900.ms, delay: delay)
        .fadeIn(duration: 250.ms, delay: delay)
        // sink into the slot
        .then()
        .moveY(begin: -8, end: 6, duration: 500.ms, curve: Curves.easeIn)
        .scaleXY(begin: 1.0, end: 0.45, duration: 500.ms, curve: Curves.easeIn)
        .fadeOut(duration: 450.ms);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _coin(
            size: 34,
            color: const Color(0xFFFFD700),
            dx: -22,
            delay: 300.ms,
          ),
          _coin(
            size: 26,
            color: const Color(0xFFFDE047),
            dx: 24,
            delay: 900.ms,
          ),
          _coin(
            size: 22,
            color: const Color(0xFFFBBF24),
            dx: -4,
            delay: 1500.ms,
          ),

          // Wallet body — scales up with an elastic settle on entry, then
          // breathes gently.
          Container(
            width: 92,
            height: 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top flap
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
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
                      border:
                          Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              // entrance
              .scaleXY(
                begin: 0.3,
                end: 1.0,
                duration: 900.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 400.ms)
              // gentle breathing loop afterwards
              .then()
              .custom(
                duration: 1600.ms,
                curve: Curves.easeInOutSine,
                builder: (_, value, child) => Transform.scale(
                  scale: 1.0 + 0.04 * math.sin(value * math.pi * 2),
                  child: child,
                ),
              )
              .shimmer(
                color: Colors.white.withValues(alpha: 0.3),
                duration: 2200.ms,
                delay: 200.ms,
              ),
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
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 300.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.6,
                end: 0,
                duration: 800.ms,
                delay: 300.ms,
                curve: Curves.easeOutCubic,
              ),
        );
      },
    );
  }
}

/// Slim, rounded determinate bar that fills as the splash plays out.
class _LoadingBar extends StatelessWidget {
  final AnimationController controller;
  const _LoadingBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 3,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final value = Curves.easeInOut.transform(controller.value);
          return Stack(
            children: [
              // track
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // fill
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
      old.float1 != float1 ||
      old.float2 != float2 ||
      old.float3 != float3 ||
      old.float4 != float4;
}

class _ParticleData {
  final double x;
  final double y;
  final double radius;
  final Color color;
  const _ParticleData(this.x, this.y, this.radius, this.color);
}

class _SawTooth extends Curve {
  final double phaseOffset;
  const _SawTooth(this.phaseOffset);

  @override
  double transformInternal(double t) {
    return ((t + phaseOffset) % 1.0).toDouble();
  }
}
