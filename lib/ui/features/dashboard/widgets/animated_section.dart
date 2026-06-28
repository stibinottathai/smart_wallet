import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Wraps a screen section with a smooth entrance animation that combines a
/// fade, an upward slide, and a gentle scale-up so each container "settles in"
/// as the page lands. [index] staggers the start so sections cascade in one
/// after another.
///
/// When [tabIndex] is provided, the entrance replays every time that bottom-nav
/// tab becomes active (the screens live in an [IndexedStack], so they're built
/// once at launch — without this they would animate while off-screen and be
/// done before the user ever arrives). Leave [tabIndex] null for content that
/// is freshly built each time it appears (e.g. a pushed route).
class AnimatedSection extends ConsumerStatefulWidget {
  final int index;
  final int? tabIndex;
  final Widget child;

  const AnimatedSection({
    super.key,
    required this.index,
    this.tabIndex,
    required this.child,
  });

  @override
  ConsumerState<AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends ConsumerState<AnimatedSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = curve;
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(curve);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(curve);

    // Play immediately when this section isn't tied to a tab, or its tab is the
    // one already on screen (covers the case where the screen's data finishes
    // loading after the user has already switched to it).
    final tab = widget.tabIndex;
    if (tab == null || ref.read(activeTabIndexProvider) == tab) {
      _play();
    }
  }

  // Number of stagger "lanes". The delay wraps every [_staggerLanes] items so
  // long, lazily-built lists (transactions, chat) still cascade on landing
  // without deep items waiting seconds to appear. Card screens use < 12
  // sections, so their cascade is unaffected.
  static const int _staggerLanes = 12;

  void _play() {
    _controller.value = 0.0; // stay hidden during the stagger delay
    Future.delayed(Duration(milliseconds: 60 * (widget.index % _staggerLanes)), () {
      if (mounted) _controller.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replay the entrance each time this section's tab becomes active.
    if (widget.tabIndex != null) {
      ref.listen<int>(activeTabIndexProvider, (prev, next) {
        if (next == widget.tabIndex && prev != widget.tabIndex) {
          _play();
        }
      });
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
