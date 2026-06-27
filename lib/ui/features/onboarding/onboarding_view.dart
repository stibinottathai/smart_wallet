import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/lock/views/app_lock_gate.dart';
import 'package:smart_wallet/ui/features/onboarding/onboarding_prefs.dart';

/// One-time, three-page onboarding shown only on the very first launch. It
/// highlights the app's pillars — AI insights, smart expense tracking, and
/// visual analytics — using the same colour language and motion as the splash
/// screen so the first-run experience feels cohesive.
class OnboardingView extends StatefulWidget {
  /// Called once the user finishes or skips. When null (the default, first-run
  /// case) the flow advances into the main app via [AppLockGate]. Settings
  /// passes a callback so "Replay onboarding" simply pops back.
  final VoidCallback? onComplete;

  const OnboardingView({super.key, this.onComplete});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();

  /// Drives the ambient background drift + floating particles.
  late final AnimationController _ambient;

  /// Continuous page position (e.g. 1.5 while swiping between page 1 and 2),
  /// used to lerp the background accent colour smoothly.
  double _page = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      accent: AppColors.primary,
      accentSoft: AppColors.primaryLight,
      eyebrow: 'AI-Powered',
      title: 'Insights that\nthink ahead',
      body:
          'Your personal finance assistant studies your spending and surfaces '
          'smart, proactive insights — so you always know where your money goes.',
      hero: _AiInsightsHero(),
    ),
    _OnboardingPage(
      accent: AppColors.secondary,
      accentSoft: AppColors.secondaryLight,
      eyebrow: 'Effortless',
      title: 'Smart expense\ntracking',
      body:
          'Snap a receipt and let AI capture the amount and category for you. '
          'Every transaction sorted automatically, in seconds.',
      hero: _SmartExpenseHero(),
    ),
    _OnboardingPage(
      accent: AppColors.primary,
      accentSoft: AppColors.primaryLight,
      eyebrow: 'Stay on track',
      title: 'Beautiful\nanalytics & goals',
      body:
          'Rich charts, budgets and savings goals turn your numbers into a '
          'clear picture — all private and offline-first on your device.',
      hero: _AnalyticsHero(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _ambient.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page.round() >= _pages.length - 1;

  /// Lerps accent colours across page positions so the wash shifts as you swipe.
  Color get _currentAccent {
    final lo = _page.floor().clamp(0, _pages.length - 1);
    final hi = _page.ceil().clamp(0, _pages.length - 1);
    return Color.lerp(
          _pages[lo].accent,
          _pages[hi].accent,
          _page - _page.floorToDouble(),
        ) ??
        _pages[lo].accent;
  }

  Color get _currentAccentSoft {
    final lo = _page.floor().clamp(0, _pages.length - 1);
    final hi = _page.ceil().clamp(0, _pages.length - 1);
    return Color.lerp(
          _pages[lo].accentSoft,
          _pages[hi].accentSoft,
          _page - _page.floorToDouble(),
        ) ??
        _pages[lo].accentSoft;
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (!mounted) return;
    // Replay mode (launched from Settings): just hand control back.
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppLockGate(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.06, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _currentAccent;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient drifting wash + particles, tinted by the active page accent.
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _AmbientPainter(
                shift: _ambient.value,
                accent: accent,
                accentSoft: _currentAccentSoft,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Skip — hidden on the last page where the CTA takes over.
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: TextButton(
                        onPressed: _isLast ? null : _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    itemBuilder: (context, i) =>
                        _OnboardingPageContent(page: _pages[i]),
                  ),
                ),
                _PageDots(
                  count: _pages.length,
                  page: _page,
                  accent: accent,
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _PrimaryButton(
                    label: _isLast ? 'Get Started' : 'Next',
                    accent: accent,
                    onPressed: _next,
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

// ── Page model + content ─────────────────────────────────────────────────────

class _OnboardingPage {
  final Color accent;
  final Color accentSoft;
  final String eyebrow;
  final String title;
  final String body;
  final Widget hero;

  const _OnboardingPage({
    required this.accent,
    required this.accentSoft,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.hero,
  });
}

class _OnboardingPageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          // Hero illustration.
          Expanded(
            flex: 10,
            child: Center(
              child: page.hero
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .scaleXY(
                    begin: 0.92,
                    end: 1.0,
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
          ),
          const Spacer(),
          // Eyebrow pill.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: page.accentSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              page.eyebrow.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: page.accent,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 500.ms)
              .slideY(begin: 0.4, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 16),
          Text(
            page.title,
            style: GoogleFonts.fraunces(
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: AppColors.text,
            ),
          )
              .animate()
              .fadeIn(delay: 250.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          Text(
            page.body,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          )
              .animate()
              .fadeIn(delay: 350.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ── Bottom controls ──────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int count;
  final double page;
  final Color accent;
  const _PageDots({
    required this.count,
    required this.page,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        // Proximity of this dot to the current page (1 = active, 0 = far).
        final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 7,
          width: 7 + 20 * t,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.divider,
              accent,
              t,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero illustrations ───────────────────────────────────────────────────────

/// A glassy card scaffold shared by every hero so the three illustrations feel
/// like a set. Children are layered on top of a soft tinted gradient.
class _HeroCard extends StatelessWidget {
  final Color accent;
  final Color accentSoft;
  final Widget child;
  const _HeroCard({
    required this.accent,
    required this.accentSoft,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentSoft.withValues(alpha: 0.55),
            AppColors.card.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small frosted pill used to float feature snippets around the heroes.
class _FloatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  const _FloatingChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightsHero extends StatelessWidget {
  const _AiInsightsHero();

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _HeroCard(
            accent: accent,
            accentSoft: AppColors.primaryLight,
            child: Center(
              // Pulsing AI orb with a glowing halo.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                        begin: 0.85,
                        end: 1.15,
                        duration: 1800.ms,
                        curve: Curves.easeInOut,
                      ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 42,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                        color: Colors.white.withValues(alpha: 0.4),
                        duration: 2400.ms,
                      ),
                ],
              ),
            ),
          ),
          // Floating insight snippets.
          Positioned(
            top: 18,
            left: -8,
            child: const _FloatingChip(
              icon: Icons.trending_down_rounded,
              label: 'Dining −18%',
              accent: accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -6, end: 6, duration: 2600.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: 30,
            right: -10,
            child: const _FloatingChip(
              icon: Icons.savings_rounded,
              label: 'On track to save',
              accent: accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 6, end: -6, duration: 3000.ms, curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }
}

class _SmartExpenseHero extends StatelessWidget {
  const _SmartExpenseHero();

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.secondary;
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _HeroCard(
            accent: accent,
            accentSoft: AppColors.secondaryLight,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Receipt.
                  Container(
                    width: 110,
                    height: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            color: accent, size: 22),
                        const SizedBox(height: 12),
                        _line(0.9, accent.withValues(alpha: 0.25)),
                        _line(0.6, AppColors.divider),
                        _line(0.75, AppColors.divider),
                        const Spacer(),
                        _line(0.5, accent.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                  // Scan line sweeping over the receipt.
                  Container(
                    width: 130,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          accent.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(
                        begin: -64,
                        end: 64,
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      ),
                ],
              ),
            ),
          ),
          // Auto-categorised chips popping out.
          Positioned(
            top: 26,
            right: -12,
            child: const _FloatingChip(
              icon: Icons.local_cafe_rounded,
              label: 'Coffee · \$4.50',
              accent: accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -5, end: 7, duration: 2700.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: 24,
            left: -10,
            child: const _FloatingChip(
              icon: Icons.check_circle_rounded,
              label: 'Auto-categorised',
              accent: accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 6, end: -6, duration: 3100.ms, curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }

  Widget _line(double widthFactor, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}

class _AnalyticsHero extends StatelessWidget {
  const _AnalyticsHero();

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _HeroCard(
            accent: accent,
            accentSoft: AppColors.primaryLight,
            child: Padding(
              padding: const EdgeInsets.all(34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Donut-style savings ring.
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(96, 96),
                              painter: _RingPainter(accent: accent),
                            )
                                .animate()
                                .custom(
                                  duration: 1200.ms,
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, child) => Opacity(
                                    opacity: v,
                                    child: child,
                                  ),
                                ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '72%',
                                  style: GoogleFonts.fraunces(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  'Goal',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Mini bar chart.
                  SizedBox(
                    height: 56,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _bar(0.4, accent),
                        _bar(0.7, accent),
                        _bar(0.55, AppColors.secondary),
                        _bar(0.9, accent),
                        _bar(0.65, accent),
                        _bar(0.8, AppColors.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 22,
            right: -12,
            child: const _FloatingChip(
              icon: Icons.pie_chart_rounded,
              label: 'Spending split',
              accent: accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -6, end: 6, duration: 2800.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: 26,
            left: -10,
            child: const _FloatingChip(
              icon: Icons.lock_rounded,
              label: 'Private & offline',
              accent: accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 6, end: -6, duration: 3200.ms, curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }

  Widget _bar(double heightFactor, Color color) {
    return Container(
      width: 16,
      height: 56 * heightFactor,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
    )
        .animate()
        .scaleY(
          begin: 0,
          end: 1,
          alignment: Alignment.bottomCenter,
          duration: 700.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Paints the 72%-filled savings ring for the analytics hero.
class _RingPainter extends CustomPainter {
  final Color accent;
  _RingPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    const stroke = 11.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.divider.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * 0.72,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [AppColors.primaryLight, accent],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.accent != accent;
}

// ── Ambient background ───────────────────────────────────────────────────────

/// Drifting radial wash + a few floating particles, tinted by the active page
/// accent. Mirrors the splash background so onboarding feels like a continuation.
class _AmbientPainter extends CustomPainter {
  final double shift;
  final Color accent;
  final Color accentSoft;

  _AmbientPainter({
    required this.shift,
    required this.accent,
    required this.accentSoft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = math.sin(shift * math.pi * 2);
    final rect = Offset.zero & size;

    final wash = RadialGradient(
      center: Alignment(0.4 - t * 0.2, -0.55 + t * 0.1),
      radius: 1.1,
      colors: [
        accentSoft.withValues(alpha: 0.5),
        accent.withValues(alpha: 0.05),
        Colors.transparent,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = wash.createShader(rect));

    final wash2 = RadialGradient(
      center: Alignment(-0.5 + t * 0.2, 0.7 - t * 0.15),
      radius: 1.0,
      colors: [
        accentSoft.withValues(alpha: 0.25),
        Colors.transparent,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = wash2.createShader(rect));

    // Floating particles.
    final particles = [
      [0.16, 0.20, 6.0, 0.10],
      [0.84, 0.16, 4.0, 0.08],
      [0.22, 0.42, 8.0, 0.07],
      [0.78, 0.46, 5.0, 0.09],
      [0.12, 0.62, 5.0, 0.06],
      [0.9, 0.66, 7.0, 0.05],
    ];
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final drift = math.sin((shift + i * 0.16) * math.pi * 2) * 10;
      canvas.drawCircle(
        Offset(p[0] * size.width, p[1] * size.height + drift),
        p[2],
        Paint()..color = accent.withValues(alpha: p[3]),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.shift != shift || old.accent != accent;
}
