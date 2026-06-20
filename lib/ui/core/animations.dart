import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppAnimations {
  AppAnimations._();

  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.easeOutBack;

  static PageRouteBuilder<T> fadeSlideUp<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return child.animate().fadeIn(
          duration: pageTransition,
          curve: defaultCurve,
        ).slide(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
          duration: pageTransition,
          curve: defaultCurve,
        );
      },
      transitionDuration: pageTransition,
    );
  }

  static PageRouteBuilder<T> fadeScale<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return child.animate().fadeIn(
          duration: pageTransition,
          curve: defaultCurve,
        ).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: pageTransition,
          curve: defaultCurve,
        );
      },
      transitionDuration: pageTransition,
    );
  }

  static List<T> stagger<T>(List<T> items, {int staggerMs = 40}) {
    return items;
  }
}

extension StaggeredAnimation on Widget {
  Widget fadeSlideIn({int delayMs = 0}) {
    return animate(
      delay: delayMs.ms,
      onInit: (controller) => controller.forward(),
    ).fadeIn(
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    ).slide(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget fadeSlideInRight({int delayMs = 0}) {
    return animate(
      delay: delayMs.ms,
      onInit: (controller) => controller.forward(),
    ).fadeIn(
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    ).slideX(
      begin: 0.03,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget scaleIn({int delayMs = 0}) {
    return animate(
      delay: delayMs.ms,
      onInit: (controller) => controller.forward(),
    ).scaleXY(
      begin: 0.92,
      end: 1.0,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    ).fadeIn(
      duration: 300.ms,
    );
  }

  Widget shimmerEffect() {
    return animate(onInit: (controller) {
      controller.repeat();
    }).shimmer(
      duration: 1500.ms,
      color: const Color(0x15FFFFFF),
    );
  }

  Widget pulseOnTap({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () => onTap(),
      child: this,
    );
  }
}

class StaggerColumn extends StatefulWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final int baseDelayMs;

  const StaggerColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.baseDelayMs = 50,
  });

  @override
  State<StaggerColumn> createState() => _StaggerColumnState();
}

class _StaggerColumnState extends State<StaggerColumn> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisAlignment: widget.mainAxisAlignment,
      children: List.generate(widget.children.length, (i) {
        return widget.children[i].fadeSlideIn(delayMs: i * widget.baseDelayMs);
      }),
    );
  }
}
